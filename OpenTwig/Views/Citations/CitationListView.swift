import SwiftUI

struct CitationListView: View {
    @Environment(AppState.self) private var appState
    @State private var searchText: String = ""
    @State private var selectedCitationID: String?
    @State private var showImportBibTeX: Bool = false
    @State private var showAddCitation: Bool = false

    private var filteredCitations: [CSLItem] {
        if searchText.isEmpty {
            return appState.citations
        }
        return appState.citations.filter { item in
            item.title.localizedCaseInsensitiveContains(searchText) ||
            item.id.localizedCaseInsensitiveContains(searchText) ||
            (item.author?.contains { name in
                name.displayName.localizedCaseInsensitiveContains(searchText)
            } ?? false)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            citationTable
        }
        .searchable(text: $searchText, placement: .toolbar, prompt: "Search citations")
        .navigationTitle("Citations")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    showImportBibTeX = true
                } label: {
                    Label("Import BibTeX", systemImage: "square.and.arrow.down")
                }
                .help("Import from BibTeX file")

                Button {
                    showAddCitation = true
                } label: {
                    Label("Add Citation", systemImage: "plus")
                }
                .help("Add citation manually or via DOI")
            }
        }
        .sheet(isPresented: $showAddCitation) {
            AddCitationSheet()
        }
        .sheet(isPresented: $showImportBibTeX) {
            ImportBibTeXSheet()
        }
        .onChange(of: selectedCitationID) { _, newValue in
            appState.selectedCitation = appState.citations.first { $0.id == newValue }
        }
        .overlay {
            if filteredCitations.isEmpty {
                ContentUnavailableView {
                    Label("No Citations", systemImage: "book.closed")
                } description: {
                    if searchText.isEmpty {
                        Text("Add citations to your library to get started.")
                    } else {
                        Text("No citations match your search.")
                    }
                } actions: {
                    if searchText.isEmpty {
                        Button("Add Citation") {
                            showAddCitation = true
                        }
                    }
                }
            }
        }
    }

    // MARK: - Citation Table

    private var citationTable: some View {
        Table(filteredCitations, selection: $selectedCitationID) {
            TableColumn("Citekey") { item in
                Text("@\(item.id)")
                    .font(.body.monospaced())
                    .foregroundStyle(.accent)
                    .lineLimit(1)
            }
            .width(min: 100, ideal: 140)

            TableColumn("Title") { item in
                Text(item.title)
                    .lineLimit(2)
            }
            .width(min: 200, ideal: 300)

            TableColumn("Authors") { item in
                Text(authorSummary(item.author))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .width(min: 120, ideal: 180)

            TableColumn("Year") { item in
                Text(item.issued?.year.map { String($0) } ?? "--")
                    .monospacedDigit()
            }
            .width(50)

            TableColumn("Type") { item in
                Text(item.type.rawValue)
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(.controlBackgroundColor), in: Capsule())
            }
            .width(min: 80, ideal: 120)
        }
        .tableStyle(.inset(alternatesRowBackgrounds: true))
    }

    private func authorSummary(_ authors: [CSLName]?) -> String {
        guard let authors, !authors.isEmpty else { return "Unknown" }
        if authors.count == 1 {
            return authors[0].displayName
        } else if authors.count == 2 {
            return "\(authors[0].family) & \(authors[1].family)"
        } else {
            return "\(authors[0].family) et al."
        }
    }
}

// MARK: - Add Citation Sheet

private struct AddCitationSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var mode: AddMode = .doi
    @State private var doiInput: String = ""
    @State private var manualCitekey: String = ""
    @State private var manualTitle: String = ""
    @State private var manualAuthors: String = ""
    @State private var manualYear: String = ""
    @State private var manualType: CSLItemType = .articleJournal
    @State private var isLoading: Bool = false

    enum AddMode: String, CaseIterable {
        case doi = "DOI Lookup"
        case manual = "Manual Entry"
    }

    var body: some View {
        VStack(spacing: 16) {
            Text("Add Citation")
                .font(.headline)

            Picker("Mode", selection: $mode) {
                ForEach(AddMode.allCases, id: \.self) { m in
                    Text(m.rawValue).tag(m)
                }
            }
            .pickerStyle(.segmented)

            Form {
                switch mode {
                case .doi:
                    TextField("DOI (e.g. 10.1000/xyz123)", text: $doiInput)
                        .textFieldStyle(.roundedBorder)
                case .manual:
                    TextField("Citekey", text: $manualCitekey)
                    TextField("Title", text: $manualTitle)
                    TextField("Authors (comma separated)", text: $manualAuthors)
                    TextField("Year", text: $manualYear)
                    Picker("Type", selection: $manualType) {
                        ForEach([CSLItemType.articleJournal, .book, .chapter,
                                 .conferencePaper, .thesis, .report, .webpage], id: \.self) { t in
                            Text(t.rawValue).tag(t)
                        }
                    }
                }
            }
            .formStyle(.grouped)

            HStack {
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                }
                Button("Add") {
                    addCitation()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(mode == .doi ? doiInput.isEmpty : manualCitekey.isEmpty)
            }
        }
        .padding()
        .frame(width: 480, minHeight: 320)
    }

    private func addCitation() {
        if mode == .manual {
            let names = manualAuthors.split(separator: ",").map { name in
                CSLName(family: name.trimmingCharacters(in: .whitespaces))
            }
            let item = CSLItem(
                id: manualCitekey,
                type: manualType,
                title: manualTitle,
                author: names,
                issued: Int(manualYear).map { CSLDate(dateParts: [[$0]]) }
            )
            appState.citations.append(item)
        }
        dismiss()
    }
}

// MARK: - Import BibTeX Sheet

private struct ImportBibTeXSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedFile: URL?

    var body: some View {
        VStack(spacing: 16) {
            Text("Import BibTeX")
                .font(.headline)

            VStack(spacing: 8) {
                Image(systemName: "doc.text")
                    .font(.system(size: 36))
                    .foregroundStyle(.secondary)

                if let file = selectedFile {
                    Text(file.lastPathComponent)
                        .font(.body.monospaced())
                } else {
                    Text("Select a .bib file to import.")
                        .foregroundStyle(.secondary)
                }

                Button("Choose File...") {
                    chooseFile()
                }
            }
            .padding(.vertical, 24)

            HStack {
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Import") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(selectedFile == nil)
            }
        }
        .padding()
        .frame(width: 400, height: 280)
    }

    private func chooseFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.init(filenameExtension: "bib")].compactMap { $0 }
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        if panel.runModal() == .OK {
            selectedFile = panel.url
        }
    }
}

#Preview {
    NavigationStack {
        CitationListView()
            .environment(AppState())
    }
    .frame(width: 700, height: 500)
}
