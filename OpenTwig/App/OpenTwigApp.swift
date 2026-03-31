import SwiftUI

@main
struct OpenTwigApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            if appState.hasCompletedOnboarding {
                ContentView()
                    .environment(appState)
                    .frame(minWidth: 900, minHeight: 600)
            } else {
                OnboardingView()
                    .environment(appState)
                    .frame(minWidth: 900, minHeight: 600)
            }
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified(showsTitle: true))
        .defaultSize(width: 1200, height: 800)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Project...") {
                    appState.showNewProject = true
                }
                .keyboardShortcut("n", modifiers: [.command])

                Button("Clone Repository...") {
                    appState.showCloneRepo = true
                }
                .keyboardShortcut("n", modifiers: [.command, .shift])

                Divider()

                Button("New Document") {
                    appState.createNewDocument()
                }
                .keyboardShortcut("n", modifiers: [.command, .option])
            }

            CommandGroup(after: .sidebar) {
                Button("Toggle Inspector") {
                    appState.showInspector.toggle()
                }
                .keyboardShortcut("i", modifiers: [.command, .option])
            }

            CommandMenu("Git") {
                Button("Commit...") {
                    appState.showCommitSheet = true
                }
                .keyboardShortcut("k", modifiers: [.command])

                Button("Push") {
                    appState.pushChanges()
                }
                .keyboardShortcut("k", modifiers: [.command, .shift])

                Button("Pull") {
                    appState.pullChanges()
                }
                .keyboardShortcut("u", modifiers: [.command, .shift])

                Divider()

                Button("New Branch...") {
                    appState.showNewBranch = true
                }
                .keyboardShortcut("b", modifiers: [.command, .shift])
            }
        }

        Settings {
            SettingsView()
                .environment(appState)
        }
    }
}
