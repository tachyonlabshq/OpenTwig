import SwiftUI

struct DiffView: View {
    @Environment(AppState.self) private var appState
    let branchName: String

    @State private var diffs: [GitDiff] = []
    @State private var viewMode: DiffDisplayMode = .unified
    @State private var filePath: String = ""
    @State private var oldBranch: String = "main"

    // MARK: - Diff Colors (GitHub-style for academic prose readability)

    private static let additionBackground = Color(red: 0.902, green: 1.0, blue: 0.925) // #e6ffec
    private static let deletionBackground = Color(red: 1.0, green: 0.922, blue: 0.914)  // #ffebe9

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
                    Text("Unified").tag(DiffDisplayMode.unified)
                    Text("Side by Side").tag(DiffDisplayMode.sideBySide)
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
                    .font(.system(.body, design: .monospaced))
                    .lineLimit(1)
            } else {
                Text("No file selected")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HStack(spacing: 4) {
                Text(oldBranch)
                    .font(.system(.caption, design: .monospaced))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.red.opacity(0.1), in: Capsule())

                Image(systemName: "arrow.right")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Text(branchName)
                    .font(.system(.caption, design: .monospaced))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.green.opacity(0.1), in: Capsule())
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    // MARK: - Diff Content

    @ViewBuilder
    private var diffContent: some View {
        if diffs.isEmpty {
            ContentUnavailableView {
                Label("No Changes", systemImage: "doc.text.magnifyingglass")
            } description: {
                Text("No changes to display.")
            }
        } else {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(diffs.enumerated()), id: \.offset) { _, diff in
                        ForEach(diff.hunks.indices, id: \.self) { hunkIndex in
                            let hunk = diff.hunks[hunkIndex]
                            hunkHeaderView(hunk: hunk)
                            ForEach(hunk.lines.indices, id: \.self) { lineIndex in
                                let line = hunk.lines[lineIndex]
                                DiffLineRow(
                                    line: line,
                                    oldLineNumber: computeOldLineNumber(
                                        hunk: hunk,
                                        lineIndex: lineIndex
                                    ),
                                    newLineNumber: computeNewLineNumber(
                                        hunk: hunk,
                                        lineIndex: lineIndex
                                    )
                                )
                            }
                        }
                    }
                }
            }
        }
    }

    private func hunkHeaderView(hunk: DiffHunk) -> some View {
        HStack {
            Text("@@ -\(hunk.oldStart),\(hunk.oldCount) +\(hunk.newStart),\(hunk.newCount) @@")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    // MARK: - Line Number Computation

    private func computeOldLineNumber(hunk: DiffHunk, lineIndex: Int) -> Int? {
        var counter = hunk.oldStart
        for i in 0..<lineIndex {
            let lineType = hunk.lines[i].type
            if lineType == .context || lineType == .deletion {
                counter += 1
            }
        }
        let current = hunk.lines[lineIndex].type
        return current == .addition ? nil : counter
    }

    private func computeNewLineNumber(hunk: DiffHunk, lineIndex: Int) -> Int? {
        var counter = hunk.newStart
        for i in 0..<lineIndex {
            let lineType = hunk.lines[i].type
            if lineType == .context || lineType == .addition {
                counter += 1
            }
        }
        let current = hunk.lines[lineIndex].type
        return current == .deletion ? nil : counter
    }
}

// MARK: - Diff Line Row

private struct DiffLineRow: View {
    let line: DiffLine
    let oldLineNumber: Int?
    let newLineNumber: Int?

    private var backgroundColor: Color {
        switch line.type {
        case .addition:
            return Color(red: 0.902, green: 1.0, blue: 0.925) // #e6ffec
        case .deletion:
            return Color(red: 1.0, green: 0.922, blue: 0.914) // #ffebe9
        case .context:
            return .clear
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
            // Old line number gutter
            Text(oldLineNumber.map { "\($0)" } ?? "")
                .frame(width: 44, alignment: .trailing)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.tertiary)
                .padding(.trailing, 4)

            // New line number gutter
            Text(newLineNumber.map { "\($0)" } ?? "")
                .frame(width: 44, alignment: .trailing)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.tertiary)
                .padding(.trailing, 8)

            Text(prefix)
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(.secondary)

            Text(line.content)
                .font(.system(.body, design: .monospaced))
                .textSelection(.enabled)

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
