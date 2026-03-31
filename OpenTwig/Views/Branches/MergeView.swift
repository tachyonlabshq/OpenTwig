import SwiftUI

struct MergeView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var sourceBranchName: String = ""
    @State private var targetBranchName: String = ""
    @State private var conflicts: [MergeConflict] = []
    @State private var changedFiles: [ChangedFile] = []
    @State private var isMerging: Bool = false

    struct ChangedFile: Identifiable {
        let id = UUID()
        var path: String
        var additions: Int
        var deletions: Int
    }

    private var localBranches: [GitBranch] {
        appState.branches.filter { !$0.isRemote }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
            Divider()
            footer
        }
        .frame(width: 600, minHeight: 480)
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 12) {
            Text("Merge Branches")
                .font(.headline)

            HStack(spacing: 16) {
                VStack(alignment: .leading) {
                    Text("Source")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Picker("Source", selection: $sourceBranchName) {
                        Text("Select branch").tag("")
                        ForEach(localBranches) { branch in
                            Text(branch.name).tag(branch.name)
                        }
                    }
                    .labelsHidden()
                }

                Image(systemName: "arrow.right")
                    .foregroundStyle(.secondary)
                    .padding(.top, 16)

                VStack(alignment: .leading) {
                    Text("Target")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Picker("Target", selection: $targetBranchName) {
                        Text("Select branch").tag("")
                        ForEach(localBranches) { branch in
                            Text(branch.name).tag(branch.name)
                        }
                    }
                    .labelsHidden()
                }
            }
        }
        .padding()
    }

    // MARK: - Content

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if !changedFiles.isEmpty {
                    changedFilesSection
                }

                if !conflicts.isEmpty {
                    conflictsSection
                }

                if changedFiles.isEmpty && conflicts.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "arrow.triangle.merge")
                            .font(.system(size: 32))
                            .foregroundStyle(.tertiary)
                        Text("Select source and target branches to preview changes.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                }
            }
            .padding()
        }
    }

    private var changedFilesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Changed Files")
                .font(.subheadline)
                .fontWeight(.semibold)

            ForEach(changedFiles) { file in
                HStack {
                    Image(systemName: "doc")
                        .foregroundStyle(.secondary)
                    Text(file.path)
                        .font(.body.monospaced())
                        .lineLimit(1)
                    Spacer()
                    HStack(spacing: 4) {
                        Text("+\(file.additions)")
                            .font(.caption.monospaced())
                            .foregroundStyle(.green)
                        Text("-\(file.deletions)")
                            .font(.caption.monospaced())
                            .foregroundStyle(.red)
                    }
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 8)
                .background(Color(.controlBackgroundColor), in: RoundedRectangle(cornerRadius: 4))
            }
        }
    }

    private var conflictsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Text("Conflicts Detected")
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }

            ForEach(conflicts) { conflict in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.red)
                        Text(conflict.path)
                            .font(.body.monospaced())
                            .lineLimit(1)
                        Spacer()
                        Button {
                            // Placeholder for AI resolution
                        } label: {
                            Label("AI Suggest", systemImage: "sparkles")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
                .padding(8)
                .background(Color(.controlBackgroundColor), in: RoundedRectangle(cornerRadius: 6))
            }
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            Button("Cancel", role: .cancel) {
                dismiss()
            }
            .keyboardShortcut(.cancelAction)

            Spacer()

            if isMerging {
                ProgressView()
                    .controlSize(.small)
                    .padding(.trailing, 8)
            }

            Button("Merge") {
                performMerge()
            }
            .keyboardShortcut(.defaultAction)
            .disabled(sourceBranchName.isEmpty || targetBranchName.isEmpty || isMerging)
        }
        .padding()
    }

    private func performMerge() {
        isMerging = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            isMerging = false
            dismiss()
        }
    }
}

#Preview {
    MergeView()
        .environment(AppState())
}
