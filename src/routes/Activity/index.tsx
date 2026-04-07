export default function Activity() {
  return (
    <div className="h-full flex items-center justify-center">
      <div className="text-center">
        <div className="font-mono text-sm text-[var(--color-fg)]">Activity</div>
        <p className="mt-2 text-xs text-[var(--color-fg-tertiary)] font-sans">
          No recent activity.
        </p>
      </div>
    </div>
  );
}
