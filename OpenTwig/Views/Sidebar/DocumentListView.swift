import SwiftUI

struct DocumentListView: View {
    @Environment(AppState.self) private var appState
    @State private var searchText: String = ""
    @State private var sortOrder: SortOrder = .name

    enum SortOrder: String, CaseIterable {
        case name = "Name"
        case dateModified = "Date Modified"
        case wordCount = "Word Count"
    }

    private var filteredDocuments: [Document] {
        var docs = appState.documents

        if !searchText.isEmpty {
            docs = docs.filter { doc in
                doc.filename.localizedCaseInsensitiveContains(searchText) ||
                doc.relativePath.localizedCaseInsensitiveContains(searchText)
            }
        }

        switch sortOrder {
        case .name:
            docs.sort { $0.filename.localizedCompare($1.filename) == .orderedAscending }
        case .dateModified:
            docs.sort { $0.lastModified > $1.lastModified }
        case .wordCount:
            docs.sort { $0.wordCount > $1.wordCount }
        }

        return docs
    }

    var body: some View {
        List(filteredDocuments, selection: Binding(
            get: { appState.selectedDocument?.id },
            set: { newID in
                appState.selectedDocument = appState.documents.first { $0.id == newID }
            }
        )) { document in
            DocumentRow(document: document)
                .tag(document.id)
                .contextMenu {
                    Button {
                        // Placeholder for rename
                    } label: {
                        Label("Rename...", systemImage: "pencil")
                    }

                    Button {
                        revealInFinder(document)
                    } label: {
                        Label("Reveal in Finder", systemImage: "folder")
                    }

                    Divider()

                    Button(role: .destructive) {
                        appState.deleteDocument(document)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
        }
        .listStyle(.inset)
        .searchable(text: $searchText, placement: .toolbar, prompt: "Search documents")
        .navigationTitle("Documents")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                sortMenu
                newDocumentButton
            }
        }
        .overlay {
            if filteredDocuments.isEmpty {
                emptyState
            }
        }
    }

    // MARK: - Toolbar Items

    private var sortMenu: some View {
        Menu {
            Picker("Sort By", selection: $sortOrder) {
                ForEach(SortOrder.allCases, id: \.self) { order in
                    Text(order.rawValue).tag(order)
                }
            }
        } label: {
            Label("Sort", systemImage: "arrow.up.arrow.down")
        }
        .help("Sort documents")
    }

    private var newDocumentButton: some View {
        Button {
            appState.createNewDocument()
        } label: {
            Label("New Document", systemImage: "plus")
        }
        .keyboardShortcut("n", modifiers: [.command, .option])
        .help("Create a new document")
    }

    // MARK: - Empty State

    @ViewBuilder
    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Documents", systemImage: "doc.text")
        } description: {
            if searchText.isEmpty {
                Text("Create a new document to get started.")
            } else {
                Text("No documents match your search.")
            }
        } actions: {
            if searchText.isEmpty {
                Button("New Document") {
                    appState.createNewDocument()
                }
            }
        }
    }

    // MARK: - Helpers

    private func revealInFinder(_ document: Document) {
        guard let projectPath = appState.selectedProject?.localPath else { return }
        let filePath = projectPath.appendingPathComponent(document.relativePath)
        NSWorkspace.shared.selectFile(filePath.path, inFileViewerRootedAtPath: "")
    }
}

// MARK: - Document Row

private struct DocumentRow: View {
    let document: Document

    var body: some View {
        HStack(spacing: 8) {
            // Modified indicator
            Circle()
                .fill(document.isModified ? Color.accentColor : .clear)
                .frame(width: 7, height: 7)

            VStack(alignment: .leading, spacing: 2) {
                Text(document.filename)
                    .font(.body)
                    .lineLimit(1)

                Text(document.relativePath)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Text("\(document.wordCount)")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color(.separatorColor).opacity(0.3), in: Capsule())
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    NavigationStack {
        DocumentListView()
            .environment(AppState())
    }
    .frame(width: 320, height: 500)
}
