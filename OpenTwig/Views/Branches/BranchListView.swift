import SwiftUI

struct BranchListView: View {
    @Environment(AppState.self) private var appState
    @State private var showNewBranch = false
    @State private var newBranchName = ""

    private var localBranches: [GitBranch] {
        appState.branches.filter { !$0.isRemote }
    }

    private var remoteBranches: [GitBranch] {
        appState.branches.filter { $0.isRemote }
    }

    var body: some View {
        List(selection: Binding(
            get: { appState.selectedBranch?.name },
            set: { newName in
                appState.selectedBranch = appState.branches.first { $0.name == newName }
            }
        )) {
            Section("Local") {
                ForEach(localBranches) { branch in
                    BranchRow(branch: branch)
                        .tag(branch.name)
                        .contextMenu {
                            Button {
                                // Placeholder: switch branch via GitService
                            } label: {
                                Label("Switch to Branch", systemImage: "arrow.left.arrow.right")
                            }
                            .disabled(branch.isCurrent)

                            Divider()

                            Button(role: .destructive) {
                                appState.branches.removeAll { $0.name == branch.name }
                            } label: {
                                Label("Delete Branch", systemImage: "trash")
                            }
                            .disabled(branch.isCurrent)
                        }
                }
            }

            if !remoteBranches.isEmpty {
                Section("Remote") {
                    ForEach(remoteBranches) { branch in
                        BranchRow(branch: branch)
                            .tag(branch.name)
                            .contextMenu {
                                Button {
                                    // Placeholder: checkout remote branch
                                } label: {
                                    Label("Checkout as Local Branch", systemImage: "arrow.down.to.line")
                                }
                            }
                    }
                }
            }
        }
        .listStyle(.inset)
        .navigationTitle("Branches")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    showNewBranch = true
                } label: {
                    Label("New Branch", systemImage: "plus")
                }
                .keyboardShortcut("b", modifiers: [.command, .shift])
                .help("Create a new branch")

                Button {
                    appState.showMergeSheet = true
                } label: {
                    Label("Merge", systemImage: "arrow.triangle.merge")
                }
                .help("Merge branches")
            }
        }
        .sheet(isPresented: $showNewBranch) {
            newBranchSheet
        }
        .overlay {
            if appState.branches.isEmpty {
                ContentUnavailableView {
                    Label("No Branches", systemImage: "arrow.triangle.branch")
                } description: {
                    Text("Open a project to see its branches.")
                }
            }
        }
    }

    // MARK: - New Branch Sheet

    private var newBranchSheet: some View {
        VStack(spacing: 16) {
            Text("Create New Branch")
                .font(.headline)

            TextField("Branch name", text: $newBranchName)
                .textFieldStyle(.roundedBorder)

            HStack {
                Button("Cancel", role: .cancel) {
                    newBranchName = ""
                    showNewBranch = false
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Create") {
                    let branch = GitBranch(
                        name: newBranchName,
                        isRemote: false,
                        isCurrent: false,
                        lastCommit: nil
                    )
                    appState.branches.append(branch)
                    newBranchName = ""
                    showNewBranch = false
                }
                .keyboardShortcut(.defaultAction)
                .disabled(newBranchName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding()
        .frame(width: 360)
    }
}

// MARK: - Branch Row

private struct BranchRow: View {
    let branch: GitBranch

    var body: some View {
        HStack(spacing: 8) {
            if branch.isCurrent {
                Image(systemName: "checkmark")
                    .font(.caption)
                    .foregroundStyle(Color.accentColor)
            } else {
                // Reserve space so rows align regardless of checkmark visibility
                Color.clear
                    .frame(width: 10, height: 10)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(branch.name)
                    .font(.system(.body, design: .monospaced))
                    .fontWeight(branch.isCurrent ? .semibold : .regular)
                    .lineLimit(1)

                if let commit = branch.lastCommit {
                    Text(commit.subject)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            if let commit = branch.lastCommit {
                Text(commit.date, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    NavigationStack {
        BranchListView()
            .environment(AppState())
    }
    .frame(width: 320, height: 500)
}
