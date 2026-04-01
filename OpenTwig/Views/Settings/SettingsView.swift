import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var appState = appState

        TabView {
            generalTab
                .tabItem {
                    Label("General", systemImage: "gear")
                }

            gitTab
                .tabItem {
                    Label("Git", systemImage: "arrow.triangle.branch")
                }

            githubTab
                .tabItem {
                    Label("GitHub", systemImage: "network")
                }

            aiTab
                .tabItem {
                    Label("AI", systemImage: "sparkles")
                }

            exportTab
                .tabItem {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
        }
        .frame(width: 520, height: 400)
    }

    // MARK: - General

    @ViewBuilder
    private var generalTab: some View {
        @Bindable var appState = appState
        Form {
            Section("Editor") {
                HStack {
                    Text("Font Size")
                    Spacer()
                    Slider(value: $appState.editorFontSize, in: 10...24, step: 1) {
                        Text("Font Size")
                    }
                    .frame(width: 160)
                    Text("\(Int(appState.editorFontSize)) pt")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .frame(width: 44, alignment: .trailing)
                }

                Picker("Theme", selection: $appState.editorTheme) {
                    Text("Default").tag("Default")
                    Text("Solarized Light").tag("Solarized Light")
                    Text("Solarized Dark").tag("Solarized Dark")
                    Text("Dracula").tag("Dracula")
                    Text("Nord").tag("Nord")
                }
            }

            Section("Setup") {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Onboarding")
                            .font(.body)
                        Text("Re-run the initial setup wizard.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Run Setup Again...") {
                        appState.hasCompletedOnboarding = false
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Git

    @ViewBuilder
    private var gitTab: some View {
        @Bindable var appState = appState
        Form {
            Section("Author") {
                TextField("Name", text: $appState.authorName)
                TextField("Email", text: $appState.authorEmail)
            }

            Section("Defaults") {
                TextField("Default Branch", text: $appState.defaultBranch)
                    .help("The default branch name when creating new repositories.")
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - GitHub

    @ViewBuilder
    private var githubTab: some View {
        @Bindable var appState = appState
        Form {
            Section("Connection") {
                HStack {
                    Label {
                        Text(appState.githubConnected ? "Connected" : "Not Connected")
                    } icon: {
                        Image(systemName: appState.githubConnected
                              ? "checkmark.circle.fill"
                              : "xmark.circle.fill")
                        .foregroundStyle(appState.githubConnected ? .green : .secondary)
                    }

                    Spacer()

                    Button(appState.githubConnected ? "Disconnect" : "Connect") {
                        appState.githubConnected.toggle()
                    }
                }
            }

            Section {
                SecureField("Personal Access Token", text: $appState.githubToken)
            } header: {
                Text("Authentication")
            } footer: {
                Text("Tokens are stored securely in Keychain.")
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - AI

    @ViewBuilder
    private var aiTab: some View {
        @Bindable var appState = appState
        Form {
            Section("API Configuration") {
                SecureField("API Key", text: $appState.aiAPIKey)

                Picker("Model", selection: $appState.aiModel) {
                    Text("Claude Sonnet 4").tag("claude-sonnet-4-20250514")
                    Text("Claude Opus 4").tag("claude-opus-4-20250514")
                    Text("Claude Haiku").tag("claude-3-5-haiku-20241022")
                }
            }

            Section {
                Toggle("Auto-suggest completions", isOn: $appState.aiAutoSuggest)
            } header: {
                Text("Features")
            } footer: {
                Text("AI suggestions help complete sentences, fix grammar, and suggest citations.")
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Export

    @ViewBuilder
    private var exportTab: some View {
        @Bindable var appState = appState
        Form {
            Section("Defaults") {
                Picker("Default Format", selection: $appState.defaultExportFormat) {
                    ForEach(ExportFormat.allCases, id: \.self) { format in
                        Text(format.rawValue).tag(format)
                    }
                }

                Picker("Citation Style", selection: $appState.defaultCitationStyle) {
                    ForEach(CitationStyle.allCases, id: \.self) { style in
                        Text(style.rawValue).tag(style)
                    }
                }
            }
        }
        .formStyle(.grouped)
    }
}

#Preview {
    SettingsView()
        .environment(AppState())
}
