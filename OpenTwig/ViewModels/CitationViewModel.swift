import Foundation
import Observation

// MARK: - Citation Type Alias

/// The project uses CSL-JSON as its canonical citation format.
/// `Citation` is an alias so the ViewModel API reads naturally.
typealias Citation = CSLItem

// MARK: - Export Format

enum CitationExportFormat: String, Sendable {
    case bibtex
    case cslJSON = "csl-json"
    case ris
}

// MARK: - CitationViewModel Errors

enum CitationError: LocalizedError, Sendable {
    case fileNotReadable(URL)
    case invalidBibTeX
    case doiLookupFailed(String)
    case exportFailed(String)

    var errorDescription: String? {
        switch self {
        case .fileNotReadable(let url):
            return "Cannot read file at \(url.path)."
        case .invalidBibTeX:
            return "The BibTeX file could not be parsed."
        case .doiLookupFailed(let doi):
            return "DOI lookup failed for \(doi)."
        case .exportFailed(let reason):
            return "Export failed: \(reason)."
        }
    }
}

// MARK: - CitationViewModel

/// Manages a library of citations (CSL items), with search, import, DOI
/// lookup, and export capabilities.
@MainActor
@Observable
final class CitationViewModel {

    // MARK: - State

    var citations: [Citation] = []
    var searchQuery: String = ""
    var selectedCitation: Citation?
    var isImporting: Bool = false

    /// Citations filtered by the current search query across title, author,
    /// and year.
    var filteredCitations: [Citation] {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return citations }
        let lowered = query.lowercased()

        return citations.filter { item in
            item.title.lowercased().contains(lowered)
                || item.author?.contains(where: { $0.displayName.lowercased().contains(lowered) }) == true
                || item.id.lowercased().contains(lowered)
                || item.issued?.year.map { String($0).contains(lowered) } == true
        }
    }

    // MARK: - Library Management

    /// Loads a CSL-JSON library from disk.
    func loadCitations(from url: URL) {
        Task {
            do {
                let data = try Data(contentsOf: url)
                let decoded = try JSONDecoder().decode([Citation].self, from: data)
                citations = decoded
            } catch {
                assertionFailure("CitationViewModel.loadCitations: \(error.localizedDescription)")
            }
        }
    }

    /// Adds a single citation to the library, deduplicating by `id`.
    func addCitation(_ citation: Citation) {
        guard !citations.contains(where: { $0.id == citation.id }) else { return }
        citations.append(citation)
    }

    /// Removes a citation by its identifier.
    func removeCitation(id: String) {
        citations.removeAll { $0.id == id }
        if selectedCitation?.id == id {
            selectedCitation = nil
        }
    }

    // MARK: - BibTeX Import

    /// Imports citations from a `.bib` file. This is a minimal parser that
    /// extracts entry type, citekey, title, author, year, and DOI fields.
    func importBibTeX(from url: URL) {
        isImporting = true

        Task {
            defer { isImporting = false }

            guard let contents = try? String(contentsOf: url, encoding: .utf8) else {
                return
            }

            let entries = parseBibTeX(contents)
            for entry in entries where !citations.contains(where: { $0.id == entry.id }) {
                citations.append(entry)
            }
        }
    }

    // MARK: - DOI Lookup

    /// Resolves a DOI to a CSL-JSON citation via the doi.org content-negotiation
    /// API (https://citation.crosscite.org/).
    func lookupDOI(_ doi: String) {
        let cleaned = doi
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "https://doi.org/", with: "")

        guard !cleaned.isEmpty else { return }

        isImporting = true

        Task {
            defer { isImporting = false }

            // Percent-encode the DOI to handle special characters (e.g., parentheses, angle brackets)
            // that are valid in DOIs but invalid in URL paths.
            guard let encoded = cleaned.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
                  let url = URL(string: "https://doi.org/\(encoded)") else { return }

            var request = URLRequest(url: url)
            request.setValue("application/vnd.citationstyles.csl+json", forHTTPHeaderField: "Accept")

            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                guard let httpResponse = response as? HTTPURLResponse,
                      (200..<300).contains(httpResponse.statusCode) else {
                    return
                }
                let citation = try JSONDecoder().decode(Citation.self, from: data)
                addCitation(citation)
                selectedCitation = citation
            } catch {
                // In production, surface this through an `error` property.
                assertionFailure("DOI lookup failed: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Export

    /// Exports the current library to disk in the specified format.
    func exportLibrary(to url: URL, format: CitationExportFormat) {
        Task {
            do {
                let data: Data
                switch format {
                case .cslJSON:
                    let encoder = JSONEncoder()
                    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                    data = try encoder.encode(citations)

                case .bibtex:
                    let bibtex = citations.map { toBibTeXEntry($0) }.joined(separator: "\n\n")
                    guard let encoded = bibtex.data(using: .utf8) else {
                        throw CitationError.exportFailed("UTF-8 encoding failed.")
                    }
                    data = encoded

                case .ris:
                    let ris = citations.map { toRISEntry($0) }.joined(separator: "\n")
                    guard let encoded = ris.data(using: .utf8) else {
                        throw CitationError.exportFailed("UTF-8 encoding failed.")
                    }
                    data = encoded
                }

                try data.write(to: url, options: .atomic)
            } catch {
                assertionFailure("CitationViewModel.exportLibrary: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - BibTeX Parsing (Minimal)

    private func parseBibTeX(_ text: String) -> [Citation] {
        // Matches @type{citekey, ... } blocks.
        let entryPattern = /@(\w+)\s*\{\s*([^,]+)\s*,([\s\S]*?)\n\s*\}/
        guard let regex = try? NSRegularExpression(pattern: entryPattern.description, options: []) else {
            return parseBibTeXManual(text)
        }
        _ = regex // NSRegularExpression approach is fragile for BibTeX; use manual parse.
        return parseBibTeXManual(text)
    }

    private func parseBibTeXManual(_ text: String) -> [Citation] {
        var results: [Citation] = []
        let scanner = Scanner(string: text)
        scanner.charactersToBeSkipped = nil

        while !scanner.isAtEnd {
            // Advance to next '@'.
            _ = scanner.scanUpToString("@")
            guard scanner.scanString("@") != nil else { break }

            guard let entryType = scanner.scanUpToString("{"),
                  scanner.scanString("{") != nil,
                  let citekey = scanner.scanUpToString(","),
                  scanner.scanString(",") != nil else {
                continue
            }

            // Collect fields until a closing brace at the start of a line.
            guard let body = scanner.scanUpToString("\n}") else { continue }
            _ = scanner.scanString("\n}")

            let fields = parseBibTeXFields(body)
            let cslType = mapBibTeXType(entryType.lowercased())

            let authors: [CSLName]? = fields["author"].map { raw in
                raw.components(separatedBy: " and ").map { name in
                    let parts = name.trimmingCharacters(in: .whitespaces)
                        .components(separatedBy: ",")
                    if parts.count >= 2 {
                        return CSLName(family: parts[0].trimmingCharacters(in: .whitespaces),
                                       given: parts[1].trimmingCharacters(in: .whitespaces))
                    }
                    return CSLName(family: parts[0].trimmingCharacters(in: .whitespaces))
                }
            }

            let issued: CSLDate? = fields["year"].flatMap { yearStr in
                guard let year = Int(yearStr) else { return nil }
                return CSLDate(dateParts: [[year]])
            }

            let item = Citation(
                id: citekey.trimmingCharacters(in: .whitespacesAndNewlines),
                type: cslType,
                title: fields["title"] ?? "Untitled",
                author: authors,
                issued: issued,
                containerTitle: fields["journal"] ?? fields["booktitle"],
                volume: fields["volume"],
                issue: fields["number"],
                page: fields["pages"],
                doi: fields["doi"],
                url: fields["url"],
                abstract: fields["abstract"]
            )

            results.append(item)
        }

        return results
    }

    private func parseBibTeXFields(_ body: String) -> [String: String] {
        var fields: [String: String] = [:]
        // Simple field pattern: key = {value} or key = "value"
        let lines = body.components(separatedBy: .newlines)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard let equalsIndex = trimmed.firstIndex(of: "=") else { continue }
            let key = trimmed[trimmed.startIndex..<equalsIndex]
                .trimmingCharacters(in: .whitespaces)
                .lowercased()
            var value = trimmed[trimmed.index(after: equalsIndex)...]
                .trimmingCharacters(in: .whitespaces)
            // Strip braces or quotes.
            if value.hasPrefix("{") && value.hasSuffix("}") ||
               value.hasPrefix("{") && value.hasSuffix("},") {
                value = String(value.dropFirst().dropLast())
                if value.hasSuffix(",") { value = String(value.dropLast()) }
            } else if value.hasSuffix(",") {
                value = String(value.dropLast())
            }
            value = value.trimmingCharacters(in: CharacterSet(charactersIn: "{}\""))
            fields[key] = value
        }
        return fields
    }

    private func mapBibTeXType(_ bibtex: String) -> CSLItemType {
        switch bibtex {
        case "article": return .articleJournal
        case "book": return .book
        case "inbook", "incollection": return .chapter
        case "inproceedings", "conference": return .conferencePaper
        case "phdthesis", "mastersthesis": return .thesis
        case "techreport": return .report
        case "misc": return .article
        default: return .article
        }
    }

    // MARK: - BibTeX Export

    private func toBibTeXEntry(_ item: Citation) -> String {
        var lines: [String] = []
        let type: String
        switch item.type {
        case .articleJournal: type = "article"
        case .book: type = "book"
        case .chapter: type = "incollection"
        case .conferencePaper: type = "inproceedings"
        case .thesis: type = "phdthesis"
        case .report: type = "techreport"
        default: type = "misc"
        }

        lines.append("@\(type){\(item.id),")
        lines.append("  title = {\(item.title)},")
        if let authors = item.author {
            let authorStr = authors.map { $0.displayName }.joined(separator: " and ")
            lines.append("  author = {\(authorStr)},")
        }
        if let year = item.issued?.year {
            lines.append("  year = {\(year)},")
        }
        if let journal = item.containerTitle {
            lines.append("  journal = {\(journal)},")
        }
        if let vol = item.volume { lines.append("  volume = {\(vol)},") }
        if let doi = item.doi { lines.append("  doi = {\(doi)},") }
        lines.append("}")
        return lines.joined(separator: "\n")
    }

    // MARK: - RIS Export

    private func toRISEntry(_ item: Citation) -> String {
        var lines: [String] = []
        lines.append("TY  - JOUR")
        lines.append("TI  - \(item.title)")
        if let authors = item.author {
            for author in authors {
                lines.append("AU  - \(author.displayName)")
            }
        }
        if let year = item.issued?.year {
            lines.append("PY  - \(year)")
        }
        if let journal = item.containerTitle {
            lines.append("JO  - \(journal)")
        }
        if let doi = item.doi { lines.append("DO  - \(doi)") }
        if let url = item.url { lines.append("UR  - \(url)") }
        lines.append("ER  -")
        lines.append("")
        return lines.joined(separator: "\n")
    }
}
