import Foundation

// MARK: - MarkdownParser

/// Pure-Swift Markdown analysis utilities. No external dependencies.
/// These are lightweight, regex-based helpers for editor features -- not a
/// full CommonMark parser.
enum MarkdownParser {

    // MARK: - Front Matter

    /// Extracts YAML front matter delimited by `---` at the start of the string.
    /// Returns key-value pairs for simple `key: value` lines.
    static func extractFrontMatter(from text: String) -> [String: String]? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("---") else { return nil }

        // Find the closing `---`.
        let afterOpen = trimmed.index(trimmed.startIndex, offsetBy: 3)
        guard let closeRange = trimmed.range(
            of: "\n---",
            range: afterOpen..<trimmed.endIndex
        ) else {
            return nil
        }

        let yamlBlock = trimmed[afterOpen..<closeRange.lowerBound]
        var result: [String: String] = [:]

        for line in yamlBlock.split(separator: "\n") {
            guard let colonIndex = line.firstIndex(of: ":") else { continue }
            let key = line[line.startIndex..<colonIndex]
                .trimmingCharacters(in: .whitespaces)
            let value = line[line.index(after: colonIndex)...]
                .trimmingCharacters(in: .whitespaces)
                .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
            guard !key.isEmpty else { continue }
            result[key] = value
        }

        return result.isEmpty ? nil : result
    }

    // MARK: - Citation Keys

    /// Extracts Pandoc-style citation keys: `@citekey` or `[@citekey]`.
    /// Returns unique keys in the order they first appear.
    static func extractCitekeys(from text: String) -> [String] {
        // Pattern matches @citekey where citekey is alphanumeric plus - _ : .
        guard let regex = try? NSRegularExpression(
            pattern: #"@([A-Za-z][A-Za-z0-9_:.\-]*)"#,
            options: []
        ) else {
            return []
        }

        let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
        let matches = regex.matches(in: text, options: [], range: nsRange)

        var seen: Set<String> = []
        var keys: [String] = []

        for match in matches {
            guard let keyRange = Range(match.range(at: 1), in: text) else { continue }
            let key = String(text[keyRange])
            if seen.insert(key).inserted {
                keys.append(key)
            }
        }

        return keys
    }

    // MARK: - Word & Sentence Counts

    /// Counts words, excluding front matter and Markdown syntax tokens.
    static func wordCount(_ text: String) -> Int {
        let body = stripFrontMatter(text)
        return body.split { $0.isWhitespace || $0.isNewline }.count
    }

    /// Counts sentences using locale-aware boundary detection.
    static func sentenceCount(_ text: String) -> Int {
        let body = stripFrontMatter(text)
        guard !body.isEmpty else { return 0 }

        var count = 0
        body.enumerateSubstrings(
            in: body.startIndex..<body.endIndex,
            options: [.bySentences, .substringNotRequired]
        ) { _, _, _, _ in
            count += 1
        }
        return count
    }

    // MARK: - Headings

    /// Extracts ATX headings (`# Heading`) with their level, text, and range
    /// within the source string.
    static func extractHeadings(from text: String) -> [(level: Int, text: String, range: Range<String.Index>)] {
        guard let regex = try? NSRegularExpression(
            pattern: #"^(#{1,6})\s+(.+)$"#,
            options: .anchorsMatchLines
        ) else {
            return []
        }

        let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
        let matches = regex.matches(in: text, options: [], range: nsRange)

        return matches.compactMap { match in
            guard let fullRange = Range(match.range, in: text),
                  let hashRange = Range(match.range(at: 1), in: text),
                  let titleRange = Range(match.range(at: 2), in: text) else {
                return nil
            }
            let level = text[hashRange].count
            let title = String(text[titleRange]).trimmingCharacters(in: .whitespaces)
            return (level: level, text: title, range: fullRange)
        }
    }

    // MARK: - Semantic Line Breaks

    /// Applies semantic line breaks (one line per sentence) to prose paragraphs.
    /// Preserves headings, code blocks, lists, and blank lines.
    static func applySemanticLineBreaks(to text: String) -> String {
        var result: [String] = []
        var inCodeBlock = false
        let lines = text.components(separatedBy: "\n")

        var paragraphBuffer: [String] = []

        func flushParagraph() {
            guard !paragraphBuffer.isEmpty else { return }
            let joined = paragraphBuffer.joined(separator: " ")
            let sentences = splitIntoSentences(joined)
            result.append(contentsOf: sentences)
            paragraphBuffer.removeAll()
        }

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Toggle code fences.
            if trimmed.hasPrefix("```") || trimmed.hasPrefix("~~~") {
                flushParagraph()
                inCodeBlock.toggle()
                result.append(line)
                continue
            }

            if inCodeBlock {
                result.append(line)
                continue
            }

            // Preserve blank lines, headings, list items, block quotes, and
            // horizontal rules as-is.
            if trimmed.isEmpty
                || trimmed.hasPrefix("#")
                || trimmed.hasPrefix("-")
                || trimmed.hasPrefix("*") && trimmed.count > 2
                || trimmed.hasPrefix(">")
                || trimmed.hasPrefix("---")
                || trimmed.hasPrefix("| ") {
                flushParagraph()
                result.append(line)
                continue
            }

            paragraphBuffer.append(trimmed)
        }

        flushParagraph()

        return result.joined(separator: "\n")
    }

    // MARK: - Private Helpers

    /// Splits prose text into sentences.
    private static func splitIntoSentences(_ text: String) -> [String] {
        var sentences: [String] = []
        text.enumerateSubstrings(
            in: text.startIndex..<text.endIndex,
            options: .bySentences
        ) { substring, _, _, _ in
            if let s = substring?.trimmingCharacters(in: .whitespaces), !s.isEmpty {
                sentences.append(s)
            }
        }
        return sentences.isEmpty ? [text] : sentences
    }

    /// Removes YAML front matter from text for counting purposes.
    private static func stripFrontMatter(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("---") else { return text }
        let afterOpen = trimmed.index(trimmed.startIndex, offsetBy: 3)
        guard let closeRange = trimmed.range(of: "\n---", range: afterOpen..<trimmed.endIndex) else {
            return text
        }
        let afterClose = trimmed.index(closeRange.upperBound, offsetBy: 0)
        return String(trimmed[afterClose...]).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
