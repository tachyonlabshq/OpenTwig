import SwiftUI

struct EditorToolbar: ToolbarContent {
    @Environment(AppState.self) private var appState

    var body: some ToolbarContent {
        ToolbarItemGroup(placement: .automatic) {
            Group {
                Button {
                    wrapSelection(prefix: "**", suffix: "**")
                } label: {
                    Text("B").bold()
                }
                .help("Bold (Cmd+B)")
                .keyboardShortcut("b", modifiers: [.command])

                Button {
                    wrapSelection(prefix: "*", suffix: "*")
                } label: {
                    Text("I").italic()
                }
                .help("Italic (Cmd+I)")
                .keyboardShortcut("i", modifiers: [.command])

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

                Divider()

                Button {
                    wrapSelection(prefix: "[", suffix: "](url)")
                } label: {
                    Label("Link", systemImage: "link")
                }
                .help("Insert link")

                Button {
                    insertText("![Alt text](image-url)")
                } label: {
                    Label("Image", systemImage: "photo")
                }
                .help("Insert image")

                Button {
                    appState.showAddCitation = true
                } label: {
                    Label("Citation", systemImage: "book.closed")
                }
                .help("Insert citation")

                Button {
                    wrapSelection(prefix: "```\n", suffix: "\n```")
                } label: {
                    Label("Code Block", systemImage: "chevron.left.forwardslash.chevron.right")
                }
                .help("Insert code block")

                Divider()

                Button {
                    appState.showExportSheet = true
                } label: {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
                .help("Export document")
            }
        }
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
