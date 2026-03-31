import SwiftUI

struct OnboardingIdentityStep: View {
    @Environment(AppState.self) var appState
    @State private var name: String = ""
    @State private var email: String = ""
    var onContinue: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            Text("Who are you?")
                .font(.system(.title2, design: .monospaced, weight: .medium))
                .foregroundStyle(.primary)

            Text("These appear on your commits.")
                .font(.callout)
                .foregroundStyle(.tertiary)
                .padding(.top, 4)

            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("NAME")
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(.tertiary)

                    TextField("", text: $name, prompt: Text("Your name").foregroundStyle(.quaternary))
                        .textFieldStyle(.plain)
                        .font(.system(.body, design: .monospaced))
                }

                Divider()
                    .padding(.vertical, 16)

                VStack(alignment: .leading, spacing: 4) {
                    Text("EMAIL")
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(.tertiary)

                    TextField("", text: $email, prompt: Text("you@university.edu").foregroundStyle(.quaternary))
                        .textFieldStyle(.plain)
                        .font(.system(.body, design: .monospaced))
                }
            }
            .padding(.top, 40)

            Button(action: {
                appState.authorName = name.trimmingCharacters(in: .whitespaces)
                appState.authorEmail = email.trimmingCharacters(in: .whitespaces)
                onContinue()
            }) {
                Text("Continue")
                    .font(.body)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.accent)
            .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || email.trimmingCharacters(in: .whitespaces).isEmpty)
            .padding(.top, 40)

            Spacer()
        }
        .onAppear {
            name = appState.authorName
            email = appState.authorEmail
        }
    }
}
