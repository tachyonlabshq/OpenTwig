import { useEffect, useState } from 'react';
import { FileText, GitBranch, BookMarked, Activity as ActivityIcon, Settings as SettingsIcon, ChevronDown } from 'lucide-react';
import { useStore, SidebarSelection } from '../../store';
import { tauri, Project, safeInvoke } from '../../lib/tauri';

const NAV: { id: SidebarSelection; label: string; Icon: any }[] = [
  { id: 'documents', label: 'Documents', Icon: FileText },
  { id: 'branches', label: 'Branches', Icon: GitBranch },
  { id: 'citations', label: 'Citations', Icon: BookMarked },
  { id: 'activity', label: 'Activity', Icon: ActivityIcon },
  { id: 'settings', label: 'Settings', Icon: SettingsIcon },
];

export default function Sidebar() {
  const sel = useStore((s) => s.sidebarSelection);
  const setSel = useStore((s) => s.setSidebarSelection);
  const selectedProjectId = useStore((s) => s.selectedProjectId);
  const setSelectedProject = useStore((s) => s.setSelectedProject);
  const [projects, setProjects] = useState<Project[]>([]);
  const [open, setOpen] = useState(false);

  useEffect(() => {
    safeInvoke(() => tauri.project.list(), [] as Project[]).then(setProjects);
  }, []);

  const current = projects.find((p) => p.id === selectedProjectId);

  return (
    <div className="h-full flex flex-col">
      <div className="px-4 pt-4 pb-2 relative">
        <button
          onClick={() => setOpen((o) => !o)}
          className="w-full flex items-center justify-between font-mono text-sm text-[var(--color-fg)] hover:text-[var(--color-fg-secondary)] transition-colors"
        >
          <span className="truncate">{current?.name ?? 'No project'}</span>
          <ChevronDown size={13} strokeWidth={1.5} />
        </button>
        {open && projects.length > 0 && (
          <div className="absolute left-3 right-3 top-full mt-1 bg-[var(--color-bg-elevated)] border border-[var(--color-border)] py-1 z-10">
            {projects.map((p) => (
              <button
                key={p.id}
                onClick={() => {
                  setSelectedProject(p.id);
                  setOpen(false);
                }}
                className="w-full text-left px-3 py-1.5 font-mono text-xs text-[var(--color-fg)] hover:bg-[var(--color-bg)]"
              >
                {p.name}
              </button>
            ))}
          </div>
        )}
      </div>

      <div className="px-4 mt-6">
        <div className="uppercase tracking-widest text-[10px] text-[var(--color-fg-tertiary)] font-mono mb-2">
          Workspace
        </div>
        <nav className="space-y-px -ml-2">
          {NAV.map(({ id, label, Icon }) => {
            const active = sel === id;
            return (
              <button
                key={id}
                onClick={() => setSel(id)}
                className={`w-full flex items-center gap-2 pl-2 pr-3 py-1.5 font-mono text-xs border-l-2 transition-colors ${
                  active
                    ? 'border-[var(--color-accent)] text-[var(--color-fg)]'
                    : 'border-transparent text-[var(--color-fg-secondary)] hover:text-[var(--color-fg)]'
                }`}
              >
                <Icon size={13} strokeWidth={1.5} />
                <span>{label}</span>
              </button>
            );
          })}
        </nav>
      </div>

      <div className="mt-auto px-4 py-3 border-t border-[var(--color-border)] flex items-center justify-between">
        <span className="font-mono text-[10px] text-[var(--color-fg-tertiary)] truncate">
          {current?.current_branch ?? 'no branch'}
        </span>
        <span className="w-1.5 h-1.5 rounded-full bg-[var(--color-accent)]" />
      </div>
    </div>
  );
}
