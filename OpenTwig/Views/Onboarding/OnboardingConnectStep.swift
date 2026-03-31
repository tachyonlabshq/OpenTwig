import SwiftUI

struct OnboardingConnectStep: View {
    @Environment(AppState.self) var appState
    @State private var token: String = ""
    var onContinue: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            Text("GitHub")
                .font(.system(.title2, design: .monospaced, weight: .medium))
                .foregroundStyle(.primary)

            Text("Connect your account to push, pull,\nand collaborate.")
                .font(.callout)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.top, 4)

            VStack(alignment: .leading, spacing: 4) {
                Text("PERSONAL ACCESS TOKEN")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.tertiary)

                SecureField("", text: $token, prompt: Text("ghp_...").foregroundStyle(.quaternary))
                    .textFieldStyle(.plain)
                    .font(.system(.body, design: .monospaced))
            }
            .padding(.top, 40)

            HStack(spacing: 24) {
                Button(action: onContinue) {
                    Text("Skip")
                        .font(.body)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)

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
                .foregroundStyle(.accent)
                .disabled(token.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.top, 40)

            Spacer()
        }
    }
}
