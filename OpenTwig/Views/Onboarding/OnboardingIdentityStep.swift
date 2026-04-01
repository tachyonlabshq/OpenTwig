import SwiftUI

struct OnboardingIdentityStep: View {
    @Environment(AppState.self) var appState
    @State private var name: String = ""
    @State private var email: String = ""
    var onContinue: () -> Void

    private var canContinue: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
            && !email.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Header
            Text("Who are you?")
                .font(.system(.title2, design: .monospaced, weight: .medium))
                .foregroundStyle(.primary)

            Text("These appear on your commits.")
                .font(.callout)
                .foregroundStyle(.tertiary)
                .padding(.top, 6)

            // Fields
            VStack(alignment: .leading, spacing: 24) {
                fieldGroup(label: "NAME") {
                    TextField("", text: $name, prompt: Text("Your name").foregroundStyle(.quaternary))
                        .textFieldStyle(.plain)
                        .font(.system(.body, design: .monospaced))
                }

                fieldGroup(label: "EMAIL") {
                    TextField("", text: $email, prompt: Text("you@university.edu").foregroundStyle(.quaternary))
                        .textFieldStyle(.plain)
                        .font(.system(.body, design: .monospaced))
                }
            }
            .padding(.top, 40)

            // Action
            Button(action: {
                appState.authorName = name.trimmingCharacters(in: .whitespaces)
                appState.authorEmail = email.trimmingCharacters(in: .whitespaces)
                onContinue()
            }) {
                Text("Continue")
                    .font(.body)
            }
            .buttonStyle(.plain)
            .foregroundStyle(canContinue ? Color.accentColor : Color.accentColor.opacity(0.35))
            .disabled(!canContinue)
            .padding(.top, 40)

            Spacer()
        }
        .onAppear {
            name = appState.authorName
            email = appState.authorEmail
        }
    }

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
}
