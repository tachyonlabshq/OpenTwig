import SwiftUI

private enum ProjectMode: String, CaseIterable {
    case new = "New"
    case open = "Open"
    case clone = "Clone"
}

struct OnboardingProjectStep: View {
    @Environment(AppState.self) var appState
    @State private var mode: ProjectMode = .new
    @State private var projectName: String = ""
    @State private var folderPath: URL?
    @State private var remoteURL: String = ""

    var onComplete: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            Text("Start a project")
                .font(.system(.title2, design: .monospaced, weight: .medium))
                .foregroundStyle(.primary)

            HStack(spacing: 16) {
                ForEach(ProjectMode.allCases, id: \.self) { m in
                    Button(action: { mode = m }) {
                        Text(m.rawValue)
                            .font(.system(.callout, design: .monospaced))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(mode == m ? .primary : .tertiary)
                }
            }
            .padding(.top, 20)

            VStack(spacing: 0) {
                switch mode {
                case .new:
                    newProjectFields
                case .open:
                    openProjectFields
                case .clone:
                    cloneProjectFields
                }
            }
            .padding(.top, 24)

            Button(action: finish) {
                Text("Done")
                    .font(.body)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.accent)
            .disabled(!isValid)
            .padding(.top, 40)

            Spacer()
        }
    }

    private var newProjectFields: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text("PROJECT NAME")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.tertiary)

                TextField("", text: $projectName, prompt: Text("My Paper").foregroundStyle(.quaternary))
                    .textFieldStyle(.plain)
                    .font(.system(.body, design: .monospaced))
            }

            Divider()
                .padding(.vertical, 16)

            folderPicker
        }
    }

    private var openProjectFields: some View {
        folderPicker
    }

    private var cloneProjectFields: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text("REMOTE URL")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.tertiary)

                TextField("", text: $remoteURL, prompt: Text("https://github.com/...").foregroundStyle(.quaternary))
                    .textFieldStyle(.plain)
                    .font(.system(.body, design: .monospaced))
            }

            Divider()
                .padding(.vertical, 16)

            folderPicker
        }
    }

    private var folderPicker: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("LOCATION")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.tertiary)

                Text(folderPath?.lastPathComponent ?? "No folder selected")
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(folderPath == nil ? .tertiary : .primary)
            }

            Spacer()

            Button("Choose...") {
                chooseFolder()
            }
            .buttonStyle(.plain)
            .foregroundStyle(.accent)
            .font(.callout)
        }
    }

    private var isValid: Bool {
        switch mode {
        case .new:
            return !projectName.trimmingCharacters(in: .whitespaces).isEmpty && folderPath != nil
        case .open:
            return folderPath != nil
        case .clone:
            return !remoteURL.trimmingCharacters(in: .whitespaces).isEmpty && folderPath != nil
        }
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Choose"
        if panel.runModal() == .OK {
            folderPath = panel.url
        }
    }

    private func finish() {
        let name = mode == .new ? projectName.trimmingCharacters(in: .whitespaces) : (folderPath?.lastPathComponent ?? "Untitled")
        let project = Project(
            name: name,
            localPath: folderPath,
            remoteURL: mode == .clone ? remoteURL.trimmingCharacters(in: .whitespaces) : ""
        )
        appState.projects.append(project)
        appState.openProject(project)
        onComplete()
    }
}
