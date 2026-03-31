import SwiftUI

struct ContentView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var appState = appState

        NavigationSplitView {
            SidebarView()
        } content: {
            contentColumn
        } detail: {
            detailColumn
        }
        .navigationSplitViewStyle(.balanced)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    appState.showCommitSheet = true
                } label: {
                    Label("Commit", systemImage: "checkmark.circle")
                }
                .keyboardShortcut("k", modifiers: [.command])
                .help("Commit changes")

                Button {
                    appState.pushChanges()
                } label: {
                    Label("Push", systemImage: "arrow.up.circle")
                }
                .keyboardShortcut("k", modifiers: [.command, .shift])
                .help("Push to remote")

                Button {
                    appState.pullChanges()
                } label: {
                    Label("Pull", systemImage: "arrow.down.circle")
                }
                .keyboardShortcut("u", modifiers: [.command, .shift])
                .help("Pull from remote")
            }
        }
        .sheet(isPresented: $appState.showNewProject) {
            ProjectCreationView(mode: .newProject)
        }
        .sheet(isPresented: $appState.showCloneRepo) {
            ProjectCreationView(mode: .clone)
        }
        .sheet(isPresented: $appState.showCommitSheet) {
            CommitSheet()
        }
        .sheet(isPresented: $appState.showMergeSheet) {
            MergeView()
        }
        .sheet(isPresented: $appState.showExportSheet) {
            ExportView()
        }
    }

    // MARK: - Content Column

    @ViewBuilder
    private var contentColumn: some View {
        switch appState.sidebarSelection {
        case .documents:
            DocumentListView()
        case .branches:
            BranchListView()
        case .citations:
            CitationListView()
        case .activity:
            ActivityLogView()
        case .settings:
            Text("Settings are available via the menu.")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - Detail Column

    @ViewBuilder
    private var detailColumn: some View {
        switch appState.sidebarSelection {
        case .documents:
            if appState.selectedDocument != nil {
                EditorView()
            } else {
                placeholderView(
                    icon: "doc.text",
                    title: "No Document Selected",
                    subtitle: "Select a document from the list to begin editing."
                )
            }
        case .branches:
            if let branch = appState.selectedBranch {
                DiffView(branchName: branch.name)
            } else {
                placeholderView(
                    icon: "arrow.triangle.branch",
                    title: "No Branch Selected",
                    subtitle: "Select a branch to view its changes."
                )
            }
        case .citations:
            if let citation = appState.selectedCitation {
                CitationDetailView(citation: citation)
            } else {
                placeholderView(
                    icon: "book.closed",
                    title: "No Citation Selected",
                    subtitle: "Select a citation to view its details."
                )
            }
        case .activity:
            placeholderView(
                icon: "clock.arrow.circlepath",
                title: "Activity",
                subtitle: "Select an event to view details."
            )
        case .settings:
            placeholderView(
                icon: "gear",
                title: "Settings",
                subtitle: "Open Settings from the application menu."
            )
        }
    }

    private func placeholderView(icon: String, title: String, subtitle: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)
            Text(title)
                .font(.title2)
                .foregroundStyle(.secondary)
            Text(subtitle)
                .font(.callout)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Commit Sheet

private struct CommitSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var commitMessage: String = ""

    var body: some View {
        VStack(spacing: 16) {
            Text("Commit Changes")
                .font(.headline)

            TextEditor(text: $commitMessage)
                .font(.body.monospaced())
                .frame(minHeight: 100)
                .border(Color(.separatorColor))

            HStack {
                Button("Cancel", role: .cancel) {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Commit") {
                    appState.commitChanges(message: commitMessage)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(commitMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding()
        .frame(width: 480, height: 240)
    }
}

#Preview {
    ContentView()
        .environment(AppState())
        .frame(width: 1200, height: 800)
}
