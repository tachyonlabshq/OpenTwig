import SwiftUI

struct OnboardingConnectStep: View {
    @Environment(AppState.self) var appState
    @State private var token: String = ""
    var onContinue: () -> Void

    private var hasToken: Bool {
        !token.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Header
            Text("GitHub")
                .font(.system(.title2, design: .monospaced, weight: .medium))
                .foregroundStyle(.primary)

            Text("Connect to push, pull, and collaborate.")
                .font(.callout)
                .foregroundStyle(.tertiary)
                .padding(.top, 6)

            // Token field
            VStack(alignment: .leading, spacing: 6) {
                Text("PERSONAL ACCESS TOKEN")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .tracking(2)

                SecureField("", text: $token, prompt: Text("ghp_...").foregroundStyle(.quaternary))
                    .textFieldStyle(.plain)
                    .font(.system(.body, design: .monospaced))

                Divider()
                    .padding(.top, 4)

                Text("Stored in Keychain.")
                    .font(.caption)
                    .foregroundStyle(.quaternary)
                    .padding(.top, 2)
            }
            .padding(.top, 40)

            // Actions
            HStack {
                Button(action: onContinue) {
                    Text("Skip")
                        .font(.body)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)

                Spacer()

                Button(action: {
                    let trimmed = token.trimmingCharacters(in: .whitespaces)
                    if !trimmed.isEmpty {
                        appState.githubToken = trimmed
                        appState.githubConnected = true
                    }
                    onContinue()
                }) {
                    Text("Continue")
                        .font(.body)
                }
                .buttonStyle(.plain)
                .foregroundStyle(hasToken ? Color.accentColor : Color.accentColor.opacity(0.35))
                .disabled(!hasToken)
            }
            .padding(.top, 40)

            Spacer()
        }
    }
}
