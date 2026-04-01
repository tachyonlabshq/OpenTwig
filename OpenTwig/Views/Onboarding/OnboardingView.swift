import SwiftUI

enum OnboardingStep: Int, CaseIterable {
    case welcome
    case identity
    case connect
    case project
}

struct OnboardingView: View {
    @Environment(AppState.self) var appState
    @State private var step: OnboardingStep = .welcome

    var body: some View {
        ZStack {
            Color(.windowBackgroundColor)
                .ignoresSafeArea()

            Group {
                switch step {
                case .welcome:
                    OnboardingWelcomeStep {
                        advance()
                    }
                case .identity:
                    OnboardingIdentityStep {
                        advance()
                    }
                case .connect:
                    OnboardingConnectStep {
                        advance()
                    }
                case .project:
                    OnboardingProjectStep {
                        appState.hasCompletedOnboarding = true
                    }
                }
            }
            .frame(maxWidth: 360)
            .transition(.asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            ))
        }
        .animation(.easeInOut(duration: 0.4), value: step)
    }

    private func advance() {
        guard let nextIndex = OnboardingStep(rawValue: step.rawValue + 1) else { return }
        step = nextIndex
    }
}
