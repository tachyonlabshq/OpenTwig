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
        .frame(width: 520, height: 380)
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
                        .frame(width: 40)
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
                Button("Run Setup Again...") {
                    appState.hasCompletedOnboarding = false
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
                    Label(
                        appState.githubConnected ? "Connected" : "Not Connected",
                        systemImage: appState.githubConnected
                            ? "checkmark.circle.fill" : "xmark.circle.fill"
                    )
                    .foregroundStyle(appState.githubConnected ? .green : .secondary)

                    Spacer()

                    Button(appState.githubConnected ? "Disconnect" : "Connect") {
                        appState.githubConnected.toggle()
                    }
                }
            }

            Section("Authentication") {
                SecureField("Personal Access Token", text: $appState.githubToken)
                    .textFieldStyle(.roundedBorder)
                Text("Tokens are stored securely in Keychain.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
                    .textFieldStyle(.roundedBorder)

                Picker("Model", selection: $appState.aiModel) {
                    Text("Claude Sonnet 4").tag("claude-sonnet-4-20250514")
                    Text("Claude Opus 4").tag("claude-opus-4-20250514")
                    Text("Claude Haiku").tag("claude-3-5-haiku-20241022")
                }
            }

            Section("Features") {
                Toggle("Auto-suggest completions", isOn: $appState.aiAutoSuggest)
                Text("AI suggestions help complete sentences, fix grammar, and suggest citations.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
