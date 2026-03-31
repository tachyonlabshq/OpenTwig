import SwiftUI

struct DiffView: View {
    @Environment(AppState.self) private var appState
    let branchName: String

    @State private var diffs: [GitDiff] = []
    @State private var viewMode: DiffDisplayMode = .unified
    @State private var filePath: String = ""
    @State private var oldBranch: String = "main"

    var body: some View {
        VStack(spacing: 0) {
            diffHeader
            Divider()
            diffContent
        }
        .navigationTitle("Changes")
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Picker("View Mode", selection: $viewMode) {
                    ForEach(DiffDisplayMode.allCases, id: \.self) { mode in
                        Text(mode == .unified ? "Unified" : "Side by Side").tag(mode)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
    }

    // MARK: - Header

    private var diffHeader: some View {
        HStack(spacing: 12) {
            Image(systemName: "doc.text")
                .foregroundStyle(.secondary)

            if !filePath.isEmpty {
                Text(filePath)
                    .font(.body.monospaced())
                    .lineLimit(1)
            } else {
                Text("No file selected")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HStack(spacing: 4) {
                Text(oldBranch)
                    .font(.caption.monospaced())
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.red.opacity(0.1), in: Capsule())

                Image(systemName: "arrow.right")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Text(branchName)
                    .font(.caption.monospaced())
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.green.opacity(0.1), in: Capsule())
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.controlBackgroundColor))
    }

    // MARK: - Diff Content

    @ViewBuilder
    private var diffContent: some View {
        if diffs.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: 36))
                    .foregroundStyle(.tertiary)
                Text("No changes to display.")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(diffs.enumerated()), id: \.offset) { _, diff in
                        ForEach(diff.hunks.indices, id: \.self) { hunkIndex in
                            let hunk = diff.hunks[hunkIndex]
                            hunkHeader(hunk: hunk)
                            ForEach(hunk.lines.indices, id: \.self) { lineIndex in
                                let line = hunk.lines[lineIndex]
                                DiffLineRow(
                                    line: line,
                                    lineNumber: hunk.newStart + lineIndex,
                                    viewMode: viewMode
                                )
                            }
                        }
                    }
                }
            }
        }
    }

    private func hunkHeader(hunk: DiffHunk) -> some View {
        HStack {
            Text("@@ -\(hunk.oldStart),\(hunk.oldCount) +\(hunk.newStart),\(hunk.newCount) @@")
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(.controlBackgroundColor))
    }
}

// MARK: - Diff Line Row

private struct DiffLineRow: View {
    let line: DiffLine
    let lineNumber: Int
    let viewMode: DiffDisplayMode

    private var backgroundColor: Color {
        switch line.type {
        case .addition: return Color.green.opacity(0.1)
        case .deletion: return Color.red.opacity(0.1)
        case .context: return .clear
        }
    }

    private var prefix: String {
        switch line.type {
        case .addition: return "+"
        case .deletion: return "-"
        case .context: return " "
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            Text("\(lineNumber)")
                .frame(width: 44, alignment: .trailing)
                .font(.caption.monospaced())
                .foregroundStyle(.tertiary)
                .padding(.trailing, 8)

            Text(prefix)
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(.secondary)

            Text(line.content)
                .font(.system(.body, design: .monospaced))

            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 1)
        .background(backgroundColor)
    }
}

#Preview {
    DiffView(branchName: "feature/intro")
        .environment(AppState())
        .frame(width: 800, height: 600)
}
