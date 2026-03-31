import Foundation
import Observation

// MARK: - EditorViewModel

/// Manages editor state for a single document, including cursor tracking,
/// search/replace, Markdown formatting shortcuts, and auto-save.
@MainActor
@Observable
final class EditorViewModel {

    // MARK: - State

    var document: Document?
    var isModified: Bool = false
    var cursorPosition: (line: Int, column: Int) = (1, 0)
    var searchQuery: String = ""
    var searchResults: [Range<String.Index>] = []

    private(set) var autoSaveTimer: Timer?

    /// How often auto-save fires, in seconds.
    private let autoSaveInterval: TimeInterval = 30

    // MARK: - Document Lifecycle

    /// Opens a document for editing and resets transient state.
    func open(document: Document) {
        self.document = document
        isModified = false
        cursorPosition = (1, 0)
        searchQuery = ""
        searchResults = []
        setupAutoSave()
    }

    /// Persists the current document content to disk.
    func save() {
        guard let document else { return }
        document.lastModified = .now
        document.isModified = false
        isModified = false

        guard let projectPath = resolveProjectPath(for: document) else { return }
        let fileURL = projectPath.appendingPathComponent(document.relativePath)

        do {
            try document.content.write(to: fileURL, atomically: true, encoding: .utf8)
        } catch {
            // Logging or error propagation would go here in a production build.
            assertionFailure("EditorViewModel.save failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Markdown Formatting

    /// Inserts a Pandoc-style citation at the current cursor position.
    /// Format: `[@citekey]`
    func insertCitation(citekey: String) {
        guard let document else { return }
        let citation = "[@\(citekey)]"
        let insertionIndex = index(for: cursorPosition, in: document.content)
        document.content.insert(contentsOf: citation, at: insertionIndex)
        markModified()
    }

    /// Inserts a Markdown heading at the beginning of the current line.
    func insertHeading(level: Int) {
        guard let document else { return }
        let clamped = max(1, min(level, 6))
        let prefix = String(repeating: "#", count: clamped) + " "

        let lineStart = startOfCurrentLine(in: document.content)
        document.content.insert(contentsOf: prefix, at: lineStart)
        markModified()
    }

    /// Wraps the selected text (or inserts markers) for bold: `**text**`.
    func toggleBold() {
        toggleWrap(marker: "**")
    }

    /// Wraps the selected text (or inserts markers) for italic: `*text*`.
    func toggleItalic() {
        toggleWrap(marker: "*")
    }

    // MARK: - Search & Replace

    /// Finds all occurrences of `query` in the document content.
    func find(query: String) {
        searchQuery = query
        guard let document, !query.isEmpty else {
            searchResults = []
            return
        }

        var results: [Range<String.Index>] = []
        var searchStart = document.content.startIndex

        while searchStart < document.content.endIndex,
              let range = document.content.range(
                of: query,
                options: .caseInsensitive,
                range: searchStart..<document.content.endIndex
              ) {
            results.append(range)
            searchStart = range.upperBound
        }

        searchResults = results
    }

    /// Replaces every occurrence of `query` with `replacement`.
    func replaceAll(query: String, replacement: String) {
        guard let document, !query.isEmpty else { return }

        let updated = document.content.replacingOccurrences(
            of: query,
            with: replacement,
            options: .caseInsensitive
        )

        if updated != document.content {
            document.content = updated
            markModified()
            // Re-run search so results reflect the new content.
            find(query: searchQuery)
        }
    }

    // MARK: - Auto-Save

    /// Sets up a repeating timer that saves when the document is modified.
    func setupAutoSave() {
        autoSaveTimer?.invalidate()
        autoSaveTimer = Timer.scheduledTimer(
            withTimeInterval: autoSaveInterval,
            repeats: true
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.isModified else { return }
                self.save()
            }
        }
    }

    // MARK: - Private Helpers

    private func markModified() {
        isModified = true
        document?.isModified = true
    }

    /// Converts a `(line, column)` pair into a `String.Index`.
    private func index(for position: (line: Int, column: Int), in text: String) -> String.Index {
        var currentLine = 1
        var idx = text.startIndex

        while idx < text.endIndex && currentLine < position.line {
            if text[idx] == "\n" {
                currentLine += 1
            }
            idx = text.index(after: idx)
        }

        var col = 0
        while idx < text.endIndex && col < position.column && text[idx] != "\n" {
            idx = text.index(after: idx)
            col += 1
        }

        return idx
    }

    /// Returns the index at the start of the line containing the cursor.
    private func startOfCurrentLine(in text: String) -> String.Index {
        let cursorIdx = index(for: cursorPosition, in: text)
        var idx = cursorIdx
        while idx > text.startIndex {
            let prev = text.index(before: idx)
            if text[prev] == "\n" { break }
            idx = prev
        }
        return idx
    }

    /// Wraps text at the cursor with the given marker (e.g. `**` for bold).
    /// If the cursor is already inside the markers, removes them instead.
    private func toggleWrap(marker: String) {
        guard let document else { return }
        let cursorIdx = index(for: cursorPosition, in: document.content)

        // Check if the surrounding text already has the marker.
        let markerCount = marker.count
        let textBefore = document.content[document.content.startIndex..<cursorIdx]
        let textAfter = document.content[cursorIdx..<document.content.endIndex]

        if textBefore.hasSuffix(marker) && textAfter.hasPrefix(marker) {
            // Remove existing markers.
            let removeStart = document.content.index(cursorIdx, offsetBy: -markerCount)
            let removeEnd = document.content.index(cursorIdx, offsetBy: markerCount)
            document.content.removeSubrange(removeStart..<cursorIdx)
            // After removal, the cursor index shifted; recalculate.
            let newCursorIdx = document.content.index(removeStart, offsetBy: 0)
            let afterRemoveEnd = document.content.index(newCursorIdx, offsetBy: markerCount, limitedBy: document.content.endIndex) ?? document.content.endIndex
            document.content.removeSubrange(newCursorIdx..<afterRemoveEnd)
        } else {
            // Insert markers around cursor.
            document.content.insert(contentsOf: marker + marker, at: cursorIdx)
        }

        markModified()
    }

    /// Resolves the project directory for file I/O. Returns `nil` if unknown.
    private func resolveProjectPath(for document: Document) -> URL? {
        // In a full implementation this would come from the project model.
        // For now we derive it from the document's relative path convention.
        nil
    }
}
