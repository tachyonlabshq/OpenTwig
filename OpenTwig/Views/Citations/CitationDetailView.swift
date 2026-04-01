import SwiftUI

struct CitationDetailView: View {
    @Environment(AppState.self) private var appState
    let citation: CSLItem

    @State private var isEditing: Bool = false
    @State private var editableTitle: String = ""
    @State private var editableAbstract: String = ""
    @State private var editableDOI: String = ""
    @State private var editableURL: String = ""
    @State private var editableVolume: String = ""
    @State private var editableIssue: String = ""
    @State private var editablePage: String = ""
    @State private var editableContainerTitle: String = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headerSection
                Divider()
                detailsForm
                Divider()
                referencesSection
            }
            .padding()
        }
        .navigationTitle(citation.title)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString("@\(citation.id)", forType: .string)
                } label: {
                    Label("Copy Citekey", systemImage: "doc.on.doc")
                }
                .help("Copy @citekey to clipboard")

                Button {
                    appState.insertCiteKey(citation.id)
                } label: {
                    Label("Insert", systemImage: "text.insert")
                }
                .help("Insert @citekey into document")

                Button {
                    if isEditing {
                        saveEdits()
                    }
                    isEditing.toggle()
                } label: {
                    Label(
                        isEditing ? "Done" : "Edit",
                        systemImage: isEditing ? "checkmark.circle" : "pencil"
                    )
                }
            }
        }
        .onAppear {
            loadEditableFields()
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("@\(citation.id)")
                    .font(.title3.monospaced())
                    .foregroundStyle(Color.accentColor)
                    .textSelection(.enabled)

                Spacer()

                Text(citation.type.rawValue)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(.controlBackgroundColor), in: Capsule())
            }

            Text(citation.title)
                .font(.title2)
                .fontWeight(.semibold)
                .textSelection(.enabled)

            if let authors = citation.author, !authors.isEmpty {
                Text(authors.map { $0.displayName }.joined(separator: "; "))
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }

            if let year = citation.issued?.year {
                Text(String(year))
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Details Form

    private var detailsForm: some View {
        Form {
            Section("Bibliographic Details") {
                if isEditing {
                    TextField("Title", text: $editableTitle)
                    TextField("Container Title (Journal/Book)", text: $editableContainerTitle)
                    TextField("Volume", text: $editableVolume)
                    TextField("Issue", text: $editableIssue)
                    TextField("Pages", text: $editablePage)
                } else {
                    detailRow(label: "Title", value: citation.title)
                    if let containerTitle = citation.containerTitle {
                        detailRow(label: "Published In", value: containerTitle)
                    }
                    if let volume = citation.volume {
                        detailRow(label: "Volume", value: volume)
                    }
                    if let issue = citation.issue {
                        detailRow(label: "Issue", value: issue)
                    }
                    if let page = citation.page {
                        detailRow(label: "Pages", value: page)
                    }
                }
            }

            Section("Identifiers") {
                if isEditing {
                    TextField("DOI", text: $editableDOI)
                    TextField("URL", text: $editableURL)
                } else {
                    if let doi = citation.doi {
                        detailRow(label: "DOI", value: doi)
                    }
                    if let url = citation.url {
                        detailRow(label: "URL", value: url)
                    }
                }
            }

            if let abstract = citation.abstract, !abstract.isEmpty {
                Section("Abstract") {
                    if isEditing {
                        TextEditor(text: $editableAbstract)
                            .frame(minHeight: 80)
                    } else {
                        Text(abstract)
                            .font(.body)
                            .textSelection(.enabled)
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    private func detailRow(label: String, value: String) -> some View {
        LabeledContent(label) {
            Text(value)
                .textSelection(.enabled)
        }
    }

    // MARK: - References Section

    private var referencesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Referenced In")
                .font(.headline)

            let referencingDocs = appState.documents.filter { doc in
                doc.content.contains("@\(citation.id)")
            }

            if referencingDocs.isEmpty {
                Text("This citation is not referenced in any documents.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            } else {
                ForEach(referencingDocs) { doc in
                    Button {
                        appState.selectedDocument = doc
                        appState.sidebarSelection = .documents
                    } label: {
                        HStack {
                            Image(systemName: "doc.text")
                                .foregroundStyle(.secondary)
                            Text(doc.filename)
                                .font(.body)
                            Spacer()
                            Text(doc.relativePath)
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Helpers

    private func loadEditableFields() {
        editableTitle = citation.title
        editableAbstract = citation.abstract ?? ""
        editableDOI = citation.doi ?? ""
        editableURL = citation.url ?? ""
        editableVolume = citation.volume ?? ""
        editableIssue = citation.issue ?? ""
        editablePage = citation.page ?? ""
        editableContainerTitle = citation.containerTitle ?? ""
    }

    private func saveEdits() {
        // Placeholder: in a real app, update the citation in the store
    }
}

#Preview {
    let citation = CSLItem(
        id: "smith2024",
        type: .articleJournal,
        title: "Advances in Collaborative Academic Writing",
        author: [
            CSLName(family: "Smith", given: "John"),
            CSLName(family: "Doe", given: "Jane")
        ],
        issued: CSLDate(dateParts: [[2024]]),
        containerTitle: "Journal of Digital Humanities",
        volume: "12",
        issue: "3",
        page: "45-67",
        doi: "10.1234/jdh.2024.001",
        abstract: "This paper explores collaborative approaches to academic writing using Git-based version control."
    )
    return CitationDetailView(citation: citation)
        .environment(AppState())
        .frame(width: 600, height: 700)
}
