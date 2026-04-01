import SwiftUI

struct ProjectCreationView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    let mode: Mode

    enum Mode {
        case newProject
        case clone
    }

    @State private var selectedTab: Tab
    @State private var projectName = ""
    @State private var localPath: URL?
    @State private var remoteURL = ""
    @State private var authMethod: AuthMethod = .https
    @State private var isCreating = false
    @State private var progress: Double = 0
    @State private var errorMessage: String?

    enum Tab: String, CaseIterable {
        case newProject = "New Project"
        case clone = "Clone"
    }

    enum AuthMethod: String, CaseIterable {
        case https = "HTTPS"
        case ssh = "SSH"
        case token = "Personal Access Token"
    }

    init(mode: Mode) {
        self.mode = mode
        _selectedTab = State(initialValue: mode == .clone ? .clone : .newProject)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Segmented picker header
            Picker("", selection: $selectedTab) {
                ForEach(Tab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding()
            .disabled(isCreating)

            Divider()

            // Form content
            Group {
                switch selectedTab {
                case .newProject:
                    newProjectForm
                case .clone:
                    cloneForm
                }
            }
            .frame(maxHeight: .infinity)

            // Error banner
            if let errorMessage {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.yellow)
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button {
                        self.errorMessage = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color.yellow.opacity(0.08))
            }

            Divider()
            footerButtons
        }
        .frame(width: 520, height: 420)
    }

    // MARK: - New Project Form

    private var newProjectForm: some View {
        Form {
            Section("Project Details") {
                TextField("Project Name", text: $projectName)

                HStack {
                    Text(localPath?.path(percentEncoded: false) ?? "No folder selected")
                        .foregroundStyle(localPath == nil ? .secondary : .primary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer()
                    Button("Choose...") {
                        chooseFolder()
                    }
                }

                TextField("Remote URL (optional)", text: $remoteURL)
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Clone Form

    private var cloneForm: some View {
        Form {
            Section("Repository") {
                TextField("Remote URL", text: $remoteURL)
                    .textContentType(.URL)

                Picker("Authentication", selection: $authMethod) {
                    ForEach(AuthMethod.allCases, id: \.self) { method in
                        Text(method.rawValue).tag(method)
                    }
                }
            }

            Section("Destination") {
                HStack {
                    Text(localPath?.path(percentEncoded: false) ?? "No folder selected")
                        .foregroundStyle(localPath == nil ? .secondary : .primary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer()
                    Button("Choose...") {
                        chooseFolder()
                    }
                }
            }

            if isCreating {
                Section {
                    VStack(spacing: 8) {
                        ProgressView(value: progress)
                            .tint(Color.accentColor)
                        Text("Cloning repository...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Footer

    private var footerButtons: some View {
        HStack {
            Button("Cancel", role: .cancel) {
                dismiss()
            }
            .keyboardShortcut(.cancelAction)

            Spacer()

            if isCreating {
                ProgressView()
                    .controlSize(.small)
                    .padding(.trailing, 4)
            }

            Button(selectedTab == .clone ? "Clone" : "Create") {
                performAction()
            }
            .keyboardShortcut(.defaultAction)
            .disabled(!isFormValid || isCreating)
        }
        .padding()
    }

    private var isFormValid: Bool {
        switch selectedTab {
        case .newProject:
            return !projectName.trimmingCharacters(in: .whitespaces).isEmpty
                && localPath != nil
        case .clone:
            return !remoteURL.trimmingCharacters(in: .whitespaces).isEmpty
                && localPath != nil
        }
    }

    // MARK: - Actions

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK {
            localPath = panel.url
        }
    }

    private func performAction() {
        errorMessage = nil
        isCreating = true

        switch selectedTab {
        case .newProject:
            let project = Project(
                name: projectName,
                localPath: localPath,
                remoteURL: remoteURL
            )
            appState.projects.append(project)
            appState.openProject(project)
            isCreating = false
            dismiss()

        case .clone:
            progress = 0
            Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { timer in
                progress += 0.15
                if progress >= 1.0 {
                    timer.invalidate()
                    let name = remoteURL.split(separator: "/").last
                        .map { String($0).replacingOccurrences(of: ".git", with: "") }
                        ?? "Cloned Project"
                    let project = Project(
                        name: name,
                        localPath: localPath,
                        remoteURL: remoteURL
                    )
                    appState.projects.append(project)
                    appState.openProject(project)
                    isCreating = false
                    dismiss()
                }
            }
        }
    }
}

#Preview {
    ProjectCreationView(mode: .newProject)
        .environment(AppState())
}
