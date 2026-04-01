import SwiftUI

struct ContentView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var appState = appState

        NavigationSplitView {
            SidebarView()
                .navigationSplitViewColumnWidth(ideal: 220)
        } content: {
            contentColumn
                .navigationSplitViewColumnWidth(ideal: 280)
        } detail: {
            detailColumn
        }
        .navigationSplitViewStyle(.balanced)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                gitToolbarButtons
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

    // MARK: - Git Toolbar Buttons

    @ViewBuilder
    private var gitToolbarButtons: some View {
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
            PlaceholderView(
                icon: "gear",
                title: "Settings",
                subtitle: "Open Settings from the application menu."
            )
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
                PlaceholderView(
                    icon: "doc.text",
                    title: "No Document Selected",
                    subtitle: "Select a document from the list to begin editing."
                )
            }
        case .branches:
            if let branch = appState.selectedBranch {
                DiffView(branchName: branch.name)
            } else {
                PlaceholderView(
                    icon: "arrow.triangle.branch",
                    title: "No Branch Selected",
                    subtitle: "Select a branch to view its changes."
                )
            }
        case .citations:
            if let citation = appState.selectedCitation {
                CitationDetailView(citation: citation)
            } else {
                PlaceholderView(
                    icon: "book.closed",
                    title: "No Citation Selected",
                    subtitle: "Select a citation to view its details."
                )
            }
        case .activity:
            PlaceholderView(
                icon: "clock.arrow.circlepath",
                title: "Activity",
                subtitle: "Select an event to view details."
            )
        case .settings:
            PlaceholderView(
                icon: "gear",
                title: "Settings",
                subtitle: "Open Settings from the application menu."
            )
        }
    }
}

// MARK: - Placeholder View

struct PlaceholderView: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 48, weight: .thin))
                .foregroundStyle(.quaternary)

            Text(title)
                .font(.title3)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)

            Text(subtitle)
                .font(.callout)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 260)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Commit Sheet

private struct CommitSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var commitMessage: String = ""

    private var isMessageEmpty: Bool {
        commitMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Commit Changes", systemImage: "checkmark.circle")
                .font(.headline)

            TextEditor(text: $commitMessage)
                .font(.body.monospaced())
                .frame(minHeight: 100)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color(.separatorColor), lineWidth: 1)
                )

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
                .disabled(isMessageEmpty)
            }
        }
        .padding(20)
        .frame(width: 480, height: 260)
    }
}

#Preview {
    ContentView()
        .environment(AppState())
        .frame(width: 1200, height: 800)
}
