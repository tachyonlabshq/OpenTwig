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

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Header
            Text("Start a project")
                .font(.system(.title2, design: .monospaced, weight: .medium))
                .foregroundStyle(.primary)

            // Mode selector
            modeSelector
                .padding(.top, 24)

            // Contextual fields
            Group {
                switch mode {
                case .new:
                    newProjectFields
                case .open:
                    openProjectFields
                case .clone:
                    cloneProjectFields
                }
            }
            .padding(.top, 32)

            // Action
            Button(action: finish) {
                Text("Done")
                    .font(.body)
            }
            .buttonStyle(.plain)
            .foregroundStyle(isValid ? Color.accentColor : Color.accentColor.opacity(0.35))
            .disabled(!isValid)
            .padding(.top, 40)

            Spacer()
        }
    }

    // MARK: - Mode Selector

    private var modeSelector: some View {
        HStack(spacing: 0) {
            ForEach(Array(ProjectMode.allCases.enumerated()), id: \.element) { index, m in
                if index > 0 {
                    Text("\u{00B7}")
                        .font(.system(.callout, design: .monospaced))
                        .foregroundStyle(.quaternary)
                        .padding(.horizontal, 12)
                }

                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        mode = m
                    }
                }) {
                    Text(m.rawValue)
                        .font(.system(.callout, design: .monospaced))
                        .fontWeight(mode == m ? .medium : .regular)
                }
                .buttonStyle(.plain)
                .foregroundStyle(mode == m ? .primary : .tertiary)
            }
        }
    }

    // MARK: - Field Groups

    private var newProjectFields: some View {
        VStack(alignment: .leading, spacing: 24) {
            fieldGroup(label: "PROJECT NAME") {
                TextField("", text: $projectName, prompt: Text("My Paper").foregroundStyle(.quaternary))
                    .textFieldStyle(.plain)
                    .font(.system(.body, design: .monospaced))
            }

            locationPicker
        }
    }

    private var openProjectFields: some View {
        VStack(alignment: .leading, spacing: 0) {
            locationPicker
        }
    }

    private var cloneProjectFields: some View {
        VStack(alignment: .leading, spacing: 24) {
            fieldGroup(label: "REMOTE URL") {
                TextField("", text: $remoteURL, prompt: Text("https://github.com/...").foregroundStyle(.quaternary))
                    .textFieldStyle(.plain)
                    .font(.system(.body, design: .monospaced))
            }

            locationPicker
        }
    }

    private var locationPicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("LOCATION")
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(.tertiary)
                .tracking(2)

            HStack {
                Text(folderPath?.lastPathComponent ?? "No folder selected")
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(folderPath == nil ? .tertiary : .primary)

                Spacer()

                Button("Choose\u{2026}") {
                    chooseFolder()
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.accentColor)
                .font(.callout)
            }

            Divider()
                .padding(.top, 4)
        }
    }

    // MARK: - Helpers

    private func fieldGroup<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(.tertiary)
                .tracking(2)

            content()

            Divider()
                .padding(.top, 4)
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
        let name = mode == .new
            ? projectName.trimmingCharacters(in: .whitespaces)
            : (folderPath?.lastPathComponent ?? "Untitled")
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
