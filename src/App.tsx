import { useStore } from './store';
import OnboardingFlow from './routes/Onboarding';
import MainShell from './routes/MainShell';
import DemoView from './routes/DemoView';

const DEMO = new URLSearchParams(window.location.search).get('demo') === '1';

export default function App() {
  const hasCompletedOnboarding = useStore((s) => s.hasCompletedOnboarding);
  if (DEMO) return <DemoView />;
  return (
    <div className="h-full w-full bg-bg text-fg">
      {hasCompletedOnboarding ? <MainShell /> : <OnboardingFlow />}
    </div>
  );
}
