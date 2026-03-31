import Foundation

// MARK: - Citation (Unified Model)

/// A unified citation type bridging BibTeX and CSL-JSON representations.
/// Wraps the existing CSLItem model with additional BibTeX-specific metadata.
struct CitationEntry: Identifiable, Codable, Hashable, Sendable {
    var id: String { citeKey }
    var citeKey: String
    var cslItem: CSLItem

    // Convenience accessors delegating to CSLItem.
    var title: String { cslItem.title }
    var authors: [CSLName] { cslItem.author ?? [] }
    var year: Int? { cslItem.issued?.year }
    var doi: String? { cslItem.doi }
    var type: CSLItemType { cslItem.type }
}

// MARK: - Citation Issues

enum CitationIssue: Sendable, Equatable {
    case undefinedCitekey(String)
    case unusedCitation(String)
    case duplicateCitekey(String)

    var description: String {
        switch self {
        case .undefinedCitekey(let key):
            return "Citekey '@\(key)' is used in the document but not defined in the bibliography"
        case .unusedCitation(let key):
            return "Citation '\(key)' is defined but never referenced in the document"
        case .duplicateCitekey(let key):
            return "Citekey '\(key)' is defined more than once"
        }
    }
}

// MARK: - Errors

enum CitationServiceError: LocalizedError, Sendable {
    case invalidBibTeX(String)
    case invalidCSLJSON(String)
    case doiLookupFailed(doi: String, reason: String)
    case networkError(String)
    case parsingFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidBibTeX(let msg):
            return "Invalid BibTeX: \(msg)"
        case .invalidCSLJSON(let msg):
            return "Invalid CSL-JSON: \(msg)"
        case .doiLookupFailed(let doi, let reason):
            return "DOI lookup failed for '\(doi)': \(reason)"
        case .networkError(let msg):
            return "Network error: \(msg)"
        case .parsingFailed(let msg):
            return "Parsing failed: \(msg)"
        }
    }
}

// MARK: - CitationService

struct CitationService: Sendable {

    private static let crossRefBaseURL = "https://api.crossref.org/works"

    // MARK: - BibTeX Parsing

    /// Parse a BibTeX string into an array of Citation values.
    func parseBibTeX(from bibtex: String) throws -> [CitationEntry] {
        var citations: [CitationEntry] = []

        // Match BibTeX entries: @type{citekey, ... }
        // Using a state-machine approach for brace balancing.
        let entryPattern = #"@(\w+)\s*\{\s*([^,]+)\s*,"#
        guard let entryRegex = try? NSRegularExpression(pattern: entryPattern) else {
            throw CitationServiceError.invalidBibTeX("Failed to compile entry regex")
        }

        let nsString = bibtex as NSString
        let matches = entryRegex.matches(
            in: bibtex,
            range: NSRange(location: 0, length: nsString.length)
        )

        for match in matches {
            let entryType = nsString.substring(with: match.range(at: 1)).lowercased()
            let citeKey = nsString.substring(with: match.range(at: 2))
                .trimmingCharacters(in: .whitespaces)

            // Find the matching closing brace for this entry.
            let entryStart = match.range.location
            guard let entryBody = extractBracedBlock(
                from: bibtex, startingAfter: entryStart
            ) else {
                continue
            }

            let fields = parseBibTeXFields(entryBody)

            let cslType = Self.bibTeXTypeToCsl(entryType)
            let authors = Self.parseBibTeXAuthors(fields["author"] ?? "")
            let issued = Self.parseBibTeXYear(fields["year"] ?? "")

            let cslItem = CSLItem(
                id: citeKey,
                type: cslType,
                title: fields["title"] ?? "",
                author: authors.isEmpty ? nil : authors,
                issued: issued,
                containerTitle: fields["journal"] ?? fields["booktitle"],
                volume: fields["volume"],
                issue: fields["number"],
                page: fields["pages"],
                doi: fields["doi"],
                url: fields["url"],
                abstract: fields["abstract"]
            )

            citations.append(CitationEntry(citeKey: citeKey, cslItem: cslItem))
        }

        return citations
    }

    // MARK: - CSL-JSON Parsing / Export

    func parseCSLJSON(from data: Data) throws -> [CitationEntry] {
        let decoder = JSONDecoder()
        do {
            let items = try decoder.decode([CSLItem].self, from: data)
            return items.map { CitationEntry(citeKey: $0.id, cslItem: $0) }
        } catch {
            throw CitationServiceError.invalidCSLJSON(error.localizedDescription)
        }
    }

    func exportCSLJSON(citations: [CitationEntry]) throws -> Data {
        let items = citations.map(\.cslItem)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(items)
    }

    // MARK: - BibTeX Export

    func exportBibTeX(citations: [CitationEntry]) throws -> String {
        var output = ""
        for citation in citations {
            let item = citation.cslItem
            let typeName = Self.cslTypeToBibTeX(item.type)

            output += "@\(typeName){\(citation.citeKey),\n"

            func addField(_ name: String, _ value: String?) {
                if let value, !value.isEmpty {
                    output += "  \(name) = {\(value)},\n"
                }
            }

            addField("title", item.title)

            if let authors = item.author, !authors.isEmpty {
                let authorStr = authors.map { name in
                    if let given = name.given {
                        return "\(name.family), \(given)"
                    }
                    return name.family
                }.joined(separator: " and ")
                addField("author", authorStr)
            }

            if let year = item.issued?.year {
                addField("year", String(year))
            }

            addField("journal", item.containerTitle)
            addField("volume", item.volume)
            addField("number", item.issue)
            addField("pages", item.page)
            addField("doi", item.doi)
            addField("url", item.url)
            addField("abstract", item.abstract)

            output += "}\n\n"
        }
        return output
    }

    // MARK: - DOI Lookup (CrossRef)

    func lookupDOI(_ doi: String) async throws -> CitationEntry {
        let sanitized = doi
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "https://doi.org/", with: "")

        guard !sanitized.isEmpty else {
            throw CitationServiceError.doiLookupFailed(doi: doi, reason: "Empty DOI")
        }

        guard let encoded = sanitized.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let url = URL(string: "\(Self.crossRefBaseURL)/\(encoded)")
        else {
            throw CitationServiceError.doiLookupFailed(doi: doi, reason: "Invalid DOI format")
        }

        var request = URLRequest(url: url)
        request.setValue(
            "OpenTwig/1.0 (mailto:support@opentwig.app)",
            forHTTPHeaderField: "User-Agent"
        )

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw CitationServiceError.networkError(error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw CitationServiceError.doiLookupFailed(doi: doi, reason: "HTTP error")
        }

        // CrossRef returns { status, message-type, message: { ... } }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let message = json["message"] as? [String: Any]
        else {
            throw CitationServiceError.doiLookupFailed(doi: doi, reason: "Unexpected response format")
        }

        let title = (message["title"] as? [String])?.first ?? "Unknown"

        // Parse authors.
        var authors: [CSLName] = []
        if let authorList = message["author"] as? [[String: Any]] {
            for a in authorList {
                let family = a["family"] as? String ?? ""
                let given = a["given"] as? String
                authors.append(CSLName(family: family, given: given))
            }
        }

        // Parse date.
        var issued: CSLDate?
        if let dateParts = (message["issued"] as? [String: Any])?["date-parts"] as? [[Int]] {
            issued = CSLDate(dateParts: dateParts)
        }

        // Generate a citekey: first author last name + year.
        let firstAuthor = authors.first?.family.lowercased()
            .filter(\.isLetter) ?? "unknown"
        let year = issued?.year.map(String.init) ?? ""
        let citeKey = "\(firstAuthor)\(year)"

        let cslItem = CSLItem(
            id: citeKey,
            type: .articleJournal,
            title: title,
            author: authors.isEmpty ? nil : authors,
            issued: issued,
            containerTitle: (message["container-title"] as? [String])?.first,
            volume: message["volume"] as? String,
            issue: message["issue"] as? String,
            page: message["page"] as? String,
            doi: sanitized,
            url: message["URL"] as? String,
            abstract: nil
        )

        return CitationEntry(citeKey: citeKey, cslItem: cslItem)
    }

    // MARK: - Citekey Extraction

    /// Extract citekeys from document text. Matches patterns like @smith2023, [@smith2023],
    /// and \\cite{smith2023} (LaTeX).
    func extractCitekeys(from text: String) -> [String] {
        var keys = Set<String>()
        let nsText = text as NSString

        // Pandoc/Markdown style: @citekey or [@citekey] or [-@citekey]
        let pandocPattern = #"(?<![\\@\w])@([a-zA-Z][\w:.#$%&\-+?<>~/]*)"#
        if let regex = try? NSRegularExpression(pattern: pandocPattern) {
            let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsText.length))
            for match in matches {
                keys.insert(nsText.substring(with: match.range(at: 1)))
            }
        }

        // LaTeX style: \cite{key1,key2} or \citep{key} or \citet{key} etc.
        let latexPattern = #"\\cite[tp]?\*?\{([^}]+)\}"#
        if let regex = try? NSRegularExpression(pattern: latexPattern) {
            let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsText.length))
            for match in matches {
                let keysStr = nsText.substring(with: match.range(at: 1))
                for key in keysStr.components(separatedBy: ",") {
                    let trimmed = key.trimmingCharacters(in: .whitespaces)
                    if !trimmed.isEmpty { keys.insert(trimmed) }
                }
            }
        }

        return Array(keys).sorted()
    }

    // MARK: - Citation Validation

    /// Validate citations: find undefined citekeys, unused citations, and duplicates.
    func validateCitations(document: String, library: [CitationEntry]) -> [CitationIssue] {
        var issues: [CitationIssue] = []

        let usedKeys = Set(extractCitekeys(from: document))
        let definedKeys = library.map(\.citeKey)
        let definedKeySet = Set(definedKeys)

        // Undefined citekeys: used in document but not in library.
        for key in usedKeys.sorted() {
            if !definedKeySet.contains(key) {
                issues.append(.undefinedCitekey(key))
            }
        }

        // Unused citations: in library but not used in document.
        for key in definedKeys.sorted() {
            if !usedKeys.contains(key) {
                issues.append(.unusedCitation(key))
            }
        }

        // Duplicate citekeys.
        var seen = Set<String>()
        for key in definedKeys {
            if seen.contains(key) {
                issues.append(.duplicateCitekey(key))
            }
            seen.insert(key)
        }

        return issues
    }

    // MARK: - Private: BibTeX Helpers

    /// Extract the content between the first `{` at/after startIndex and its matching `}`.
    private func extractBracedBlock(from text: String, startingAfter offset: Int) -> String? {
        let start = text.index(text.startIndex, offsetBy: offset, limitedBy: text.endIndex)
            ?? text.endIndex
        guard let openBrace = text[start...].firstIndex(of: "{") else { return nil }

        var depth = 0
        var index = openBrace
        while index < text.endIndex {
            let ch = text[index]
            if ch == "{" { depth += 1 }
            if ch == "}" {
                depth -= 1
                if depth == 0 {
                    let bodyStart = text.index(after: openBrace)
                    return String(text[bodyStart..<index])
                }
            }
            index = text.index(after: index)
        }
        return nil
    }

    /// Parse BibTeX field = {value} or field = "value" pairs.
    private func parseBibTeXFields(_ body: String) -> [String: String] {
        var fields: [String: String] = [:]

        // Match field = {value} or field = "value" or field = number
        let fieldPattern = #"(\w+)\s*=\s*(?:\{([^{}]*(?:\{[^{}]*\}[^{}]*)*)\}|"([^"]*)"|(\d+))"#
        guard let regex = try? NSRegularExpression(pattern: fieldPattern) else { return fields }

        let nsBody = body as NSString
        let matches = regex.matches(in: body, range: NSRange(location: 0, length: nsBody.length))

        for match in matches {
            let key = nsBody.substring(with: match.range(at: 1)).lowercased()
            let value: String
            if match.range(at: 2).location != NSNotFound {
                value = nsBody.substring(with: match.range(at: 2))
            } else if match.range(at: 3).location != NSNotFound {
                value = nsBody.substring(with: match.range(at: 3))
            } else if match.range(at: 4).location != NSNotFound {
                value = nsBody.substring(with: match.range(at: 4))
            } else {
                continue
            }
            fields[key] = value
        }

        return fields
    }

    /// Parse BibTeX author field ("Last1, First1 and Last2, First2").
    private static func parseBibTeXAuthors(_ authorField: String) -> [CSLName] {
        guard !authorField.isEmpty else { return [] }

        return authorField
            .components(separatedBy: " and ")
            .map { raw -> CSLName in
                let trimmed = raw.trimmingCharacters(in: .whitespaces)
                let parts = trimmed.components(separatedBy: ",")
                if parts.count >= 2 {
                    return CSLName(
                        family: parts[0].trimmingCharacters(in: .whitespaces),
                        given: parts[1].trimmingCharacters(in: .whitespaces)
                    )
                }
                // Single name or "First Last" format.
                let words = trimmed.components(separatedBy: " ")
                if words.count >= 2 {
                    return CSLName(
                        family: words.last ?? trimmed,
                        given: words.dropLast().joined(separator: " ")
                    )
                }
                return CSLName(family: trimmed, given: nil)
            }
    }

    private static func parseBibTeXYear(_ yearField: String) -> CSLDate? {
        guard let year = Int(yearField.trimmingCharacters(in: .whitespaces)) else {
            return nil
        }
        return CSLDate(dateParts: [[year]])
    }

    private static func bibTeXTypeToCsl(_ bibtexType: String) -> CSLItemType {
        switch bibtexType {
        case "article": return .articleJournal
        case "book": return .book
        case "inbook", "incollection": return .chapter
        case "inproceedings", "conference": return .conferencePaper
        case "phdthesis", "mastersthesis": return .thesis
        case "techreport": return .report
        case "misc": return .article
        case "online": return .webpage
        default: return .article
        }
    }

    private static func cslTypeToBibTeX(_ cslType: CSLItemType) -> String {
        switch cslType {
        case .articleJournal: return "article"
        case .book: return "book"
        case .chapter: return "incollection"
        case .conferencePaper: return "inproceedings"
        case .thesis: return "phdthesis"
        case .report: return "techreport"
        case .webpage: return "online"
        case .dataset: return "misc"
        case .software: return "misc"
        case .preprint: return "article"
        case .manuscript: return "unpublished"
        case .article: return "article"
        case .review: return "article"
        }
    }
}
