import SwiftUI

struct OnboardingWelcomeStep: View {
    var onContinue: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            Text("OpenTwig")
                .font(.system(.largeTitle, design: .monospaced, weight: .medium))
                .foregroundStyle(.primary)

            Text("Git-backed academic collaboration.")
                .font(.body)
                .foregroundStyle(.secondary)
                .padding(.top, 8)

            Button(action: onContinue) {
                Text("Get Started")
                    .font(.body)
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.accentColor)
            .padding(.top, 48)

            Spacer()
        }
    }
}
