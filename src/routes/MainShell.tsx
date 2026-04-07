import { useEffect, useState } from 'react';
import { GitCommit, ArrowUp, ArrowDown } from 'lucide-react';
import Sidebar from './Sidebar';
import Editor from './Editor';
import Branches from './Branches';
import Citations from './Citations';
import Activity from './Activity';
import Settings from './Settings';
import { useStore } from '../store';
import { tauri, Project, DocumentEntry, safeInvoke } from '../lib/tauri';

export default function MainShell() {
  const sel = useStore((s) => s.sidebarSelection);
  const selectedProjectId = useStore((s) => s.selectedProjectId);
  const [project, setProject] = useState<Project | null>(null);
  const [docs, setDocs] = useState<DocumentEntry[]>([]);
  const [activeDoc, setActiveDoc] = useState<DocumentEntry | null>(null);

  useEffect(() => {
    if (!selectedProjectId) return;
    safeInvoke(() => tauri.project.open(selectedProjectId), null as Project | null).then((p) => {
      if (p) setProject(p);
    });
  }, [selectedProjectId]);

  useEffect(() => {
    if (!project) return;
    safeInvoke(() => tauri.project.documents(project.id), [] as DocumentEntry[]).then((d) => {
      setDocs(d);
      setActiveDoc((cur) => cur ?? d.find((x) => !x.is_dir) ?? null);
    });
  }, [project]);

  return (
    <div className="h-full w-full flex flex-col bg-[var(--color-bg)]">
      <TopBar project={project} />
      <div className="flex-1 flex min-h-0">
        <div className="w-[220px] border-r border-[var(--color-border)] flex-shrink-0">
          <Sidebar />
        </div>
        <div className="w-[280px] border-r border-[var(--color-border)] flex-shrink-0 overflow-y-auto">
          {sel === 'documents' && (
            <DocumentList docs={docs} active={activeDoc} onSelect={setActiveDoc} />
          )}
        </div>
        <div className="flex-1 min-w-0">
          {sel === 'documents' && <Editor doc={activeDoc} />}
          {sel === 'branches' && <Branches project={project} />}
          {sel === 'citations' && <Citations />}
          {sel === 'activity' && <Activity />}
          {sel === 'settings' && <Settings />}
        </div>
      </div>
    </div>
  );
}

function TopBar({ project }: { project: Project | null }) {
  return (
    <div className="h-11 flex items-center justify-between px-4 border-b border-[var(--color-border)] bg-[var(--color-bg)]">
      <div className="font-mono text-sm text-[var(--color-fg)]">
        {project?.name ?? 'OpenTwig'}
      </div>
      <div className="flex items-center gap-4 text-[var(--color-fg-secondary)]">
        <button title="Commit" className="hover:text-[var(--color-fg)] transition-colors">
          <GitCommit size={15} strokeWidth={1.5} />
        </button>
        <button title="Pull" className="hover:text-[var(--color-fg)] transition-colors">
          <ArrowDown size={15} strokeWidth={1.5} />
        </button>
        <button title="Push" className="hover:text-[var(--color-fg)] transition-colors">
          <ArrowUp size={15} strokeWidth={1.5} />
        </button>
      </div>
    </div>
  );
}

function DocumentList({
  docs,
  active,
  onSelect,
}: {
  docs: DocumentEntry[];
  active: DocumentEntry | null;
  onSelect: (d: DocumentEntry) => void;
}) {
  if (docs.length === 0) {
    return (
      <div className="p-6 text-xs text-[var(--color-fg-tertiary)] font-mono">
        No documents yet.
      </div>
    );
  }
  return (
    <div className="py-2">
      {docs
        .filter((d) => !d.is_dir)
        .map((d) => (
          <button
            key={d.path}
            onClick={() => onSelect(d)}
            className={`w-full text-left px-4 py-2 font-mono text-xs transition-colors ${
              active?.path === d.path
                ? 'text-[var(--color-fg)] bg-[var(--color-bg-elevated)]'
                : 'text-[var(--color-fg-secondary)] hover:text-[var(--color-fg)]'
            }`}
          >
            {d.name}
          </button>
        ))}
    </div>
  );
}
