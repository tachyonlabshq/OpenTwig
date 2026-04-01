import SwiftUI

struct EditorView: View {
    @Environment(AppState.self) private var appState
    @State private var cursorPosition: (line: Int, column: Int) = (1, 0)

    private var document: Document? {
        appState.selectedDocument
    }

    private var content: Binding<String> {
        Binding(
            get: {
                guard let doc = appState.selectedDocument,
                      let index = appState.documents.firstIndex(where: { $0.id == doc.id })
                else { return "" }
                return appState.documents[index].content
            },
            set: { newValue in
                guard let doc = appState.selectedDocument,
                      let index = appState.documents.firstIndex(where: { $0.id == doc.id })
                else { return }
                appState.documents[index].content = newValue
                appState.documents[index].isModified = true
                appState.documents[index].lastModified = .now
            }
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            editorArea
            statusBar
        }
        .navigationTitle(document?.filename ?? "")
        .toolbar {
            EditorToolbar()
        }
    }

    // MARK: - Editor Area

    private var editorArea: some View {
        HStack(spacing: 0) {
            lineNumberGutter
            Divider()
            textEditor
        }
    }

    private var lineNumberGutter: some View {
        let text = content.wrappedValue
        let lineCount = max(text.components(separatedBy: "\n").count, 1)

        return ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .trailing, spacing: 0) {
                ForEach(1...lineCount, id: \.self) { lineNumber in
                    Text("\(lineNumber)")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.quaternary)
                        .frame(height: 20)
                }
            }
            .padding(.horizontal, 8)
            .padding(.top, 8)
        }
        .frame(width: 44)
        .background(Color(.controlBackgroundColor).opacity(0.4))
    }

    private var textEditor: some View {
        TextEditor(text: content)
            .font(.system(size: appState.editorFontSize, design: .monospaced))
            .scrollContentBackground(.hidden)
            .padding(8)
    }

    // MARK: - Status Bar

    private var statusBar: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 0) {
                if let doc = document {
                    statusItem(
                        label: "\(doc.wordCount) words",
                        icon: "text.word.spacing"
                    )
                    statusDivider
                    statusItem(
                        label: "\(doc.content.count) chars",
                        icon: "character.cursor.ibeam"
                    )
                    statusDivider
                    statusItem(
                        label: "Ln \(cursorPosition.line), Col \(cursorPosition.column)",
                        icon: "cursorarrow.click"
                    )
                }

                Spacer()

                if let doc = document, doc.isModified {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.accentColor)
                            .frame(width: 6, height: 6)
                        Text("Modified")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background(Color(.windowBackgroundColor))
        }
    }

    private func statusItem(label: String, icon: String) -> some View {
        Label(label, systemImage: icon)
            .font(.caption)
            .foregroundStyle(.tertiary)
    }

    private var statusDivider: some View {
        Text("\u{2022}")
            .font(.caption2)
            .foregroundStyle(.quaternary)
            .padding(.horizontal, 8)
    }
}

#Preview {
    let state = AppState()
    state.documents = [
        Document(
            filename: "chapter-1.md",
            relativePath: "chapters/chapter-1.md",
            content: "# Introduction\n\nThis is an example document.\n\nAs noted by @smith2024, the field has evolved.\n"
        )
    ]
    state.selectedDocument = state.documents.first
    return EditorView()
        .environment(state)
        .frame(width: 700, height: 500)
}
