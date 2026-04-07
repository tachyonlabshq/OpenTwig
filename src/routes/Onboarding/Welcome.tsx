import Button from '../../components/Button';

export default function Welcome({ onNext }: { onNext: () => void }) {
  return (
    <div className="text-center">
      <h1 className="font-mono text-3xl text-[var(--color-fg)] tracking-tight">OpenTwig</h1>
      <p className="mt-3 text-sm text-[var(--color-fg-secondary)] font-sans">
        Git-backed academic collaboration.
      </p>
      <div className="mt-12">
        <Button variant="primary" onClick={onNext}>
          Get Started
        </Button>
      </div>
    </div>
  );
}
