import { useEffect, useState } from 'react';
import { tauri, BranchList, Project, safeInvoke } from '../../lib/tauri';

export default function Branches({ project }: { project: Project | null }) {
  const [branches, setBranches] = useState<BranchList | null>(null);

  useEffect(() => {
    if (!project) return;
    safeInvoke(() => tauri.git.branches(project.local_path), null as BranchList | null).then(setBranches);
  }, [project?.local_path]);

  if (!branches || (branches.local.length === 0 && branches.remote.length === 0)) {
    return (
      <div className="h-full flex items-center justify-center text-[var(--color-fg-tertiary)] font-mono text-xs">
        No branches.
      </div>
    );
  }

  return (
    <div className="p-8 max-w-2xl">
      <Section title="Local" items={branches.local} current={branches.current} />
      <Section title="Remote" items={branches.remote} current={branches.current} />
    </div>
  );
}

function Section({ title, items, current }: { title: string; items: string[]; current: string }) {
  return (
    <div className="mb-10">
      <div className="uppercase tracking-widest text-[10px] text-[var(--color-fg-tertiary)] font-mono mb-3">
        {title}
      </div>
      <ul>
        {items.map((b) => (
          <li
            key={b}
            className={`py-1.5 font-mono text-sm ${
              b === current ? 'text-[var(--color-accent)]' : 'text-[var(--color-fg)]'
            }`}
          >
            {b === current ? '· ' : '  '}
            {b}
          </li>
        ))}
      </ul>
    </div>
  );
}
