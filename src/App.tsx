import { useStore } from './store';
import OnboardingFlow from './routes/Onboarding';
import MainShell from './routes/MainShell';

export default function App() {
  const hasCompletedOnboarding = useStore((s) => s.hasCompletedOnboarding);
  return (
    <div className="h-full w-full bg-bg text-fg">
      {hasCompletedOnboarding ? <MainShell /> : <OnboardingFlow />}
    </div>
  );
}
