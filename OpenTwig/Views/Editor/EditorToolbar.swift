import SwiftUI

struct EditorToolbar: ToolbarContent {
    @Environment(AppState.self) private var appState

    var body: some ToolbarContent {
        ToolbarItemGroup(placement: .automatic) {
            // Formatting group
            formatBoldButton
            formatItalicButton
            headingMenu

            Divider()

            // Insert group
            linkButton
            imageButton
            citationButton
            codeBlockButton

            Divider()

            // Export
            exportButton
        }
    }

    // MARK: - Formatting Buttons

    private var formatBoldButton: some View {
        Button {
            wrapSelection(prefix: "**", suffix: "**")
        } label: {
            Label("Bold", systemImage: "bold")
        }
        .help("Bold")
        .keyboardShortcut("b", modifiers: [.command])
    }

    private var formatItalicButton: some View {
        Button {
            wrapSelection(prefix: "*", suffix: "*")
        } label: {
            Label("Italic", systemImage: "italic")
        }
        .help("Italic")
        .keyboardShortcut("i", modifiers: [.command])
    }

    private var headingMenu: some View {
        Menu {
            ForEach(1...6, id: \.self) { level in
                Button("Heading \(level)") {
                    insertPrefix(String(repeating: "#", count: level) + " ")
                }
            }
        } label: {
            Label("Heading", systemImage: "textformat.size")
        }
        .help("Insert heading")
    }

    // MARK: - Insert Buttons

    private var linkButton: some View {
        Button {
            wrapSelection(prefix: "[", suffix: "](url)")
        } label: {
            Label("Link", systemImage: "link")
        }
        .help("Insert link")
    }

    private var imageButton: some View {
        Button {
            insertText("![Alt text](image-url)")
        } label: {
            Label("Image", systemImage: "photo")
        }
        .help("Insert image")
    }

    private var citationButton: some View {
        Button {
            appState.showAddCitation = true
        } label: {
            Label("Citation", systemImage: "book.closed")
        }
        .help("Insert citation")
    }

    private var codeBlockButton: some View {
        Button {
            wrapSelection(prefix: "```\n", suffix: "\n```")
        } label: {
            Label("Code Block", systemImage: "chevron.left.forwardslash.chevron.right")
        }
        .help("Insert code block")
    }

    // MARK: - Export

    private var exportButton: some View {
        Button {
            appState.showExportSheet = true
        } label: {
            Label("Export", systemImage: "square.and.arrow.up")
        }
        .help("Export document")
    }

    // MARK: - Text Manipulation Helpers

    private func wrapSelection(prefix: String, suffix: String) {
        guard let doc = appState.selectedDocument,
              let index = appState.documents.firstIndex(where: { $0.id == doc.id })
        else { return }
        appState.documents[index].content.append(prefix + "text" + suffix)
        appState.documents[index].isModified = true
    }

    private func insertPrefix(_ prefix: String) {
        guard let doc = appState.selectedDocument,
              let index = appState.documents.firstIndex(where: { $0.id == doc.id })
        else { return }
        appState.documents[index].content.append("\n" + prefix)
        appState.documents[index].isModified = true
    }

    private func insertText(_ text: String) {
        guard let doc = appState.selectedDocument,
              let index = appState.documents.firstIndex(where: { $0.id == doc.id })
        else { return }
        appState.documents[index].content.append(text)
        appState.documents[index].isModified = true
    }
}
