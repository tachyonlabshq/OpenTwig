import { useState } from 'react';
import { open } from '@tauri-apps/plugin-dialog';
import Field from '../../components/Field';
import Button from '../../components/Button';
import { tauri } from '../../lib/tauri';
import { useStore } from '../../store';

type Mode = 'new' | 'open' | 'clone';

export default function FirstProject({
  gitServerId,
  onDone,
}: {
  gitServerId: string | null;
  onDone: () => void;
}) {
  const [mode, setMode] = useState<Mode>('new');
  const [name, setName] = useState('');
  const [path, setPath] = useState('');
  const [remote, setRemote] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const setOnboardingComplete = useStore((s) => s.setOnboardingComplete);
  const setSelectedProject = useStore((s) => s.setSelectedProject);

  async function pickFolder() {
    try {
      const selected = await open({ directory: true, multiple: false });
      if (typeof selected === 'string') setPath(selected);
    } catch (e) {
      console.warn(e);
    }
  }

  async function handleDone() {
    if (!gitServerId) {
      setError('No git server selected');
      return;
    }
    setBusy(true);
    setError(null);
    try {
      if (mode === 'clone') {
        await tauri.git.clone(remote.trim(), path.trim(), gitServerId);
        const proj = await tauri.project.create(
          name.trim() || remote.split('/').pop()?.replace(/\.git$/, '') || 'project',
          path.trim(),
          gitServerId,
          remote.trim(),
        );
        setSelectedProject(proj.id);
      } else {
        const proj = await tauri.project.create(
          name.trim(),
          path.trim(),
          gitServerId,
          mode === 'open' ? '' : remote.trim(),
        );
        setSelectedProject(proj.id);
      }
      setOnboardingComplete();
      onDone();
    } catch (e: any) {
      setError(String(e?.message ?? e));
    } finally {
      setBusy(false);
    }
  }

  const valid =
    mode === 'clone'
      ? remote.trim() && path.trim()
      : mode === 'open'
        ? path.trim() && name.trim()
        : name.trim() && path.trim();

  return (
    <div>
      <h2 className="font-mono text-2xl text-[var(--color-fg)]">Start a project</h2>
      <div className="mt-4 flex items-center gap-3 font-mono text-sm">
        {(['new', 'open', 'clone'] as Mode[]).map((m, i) => (
          <span key={m} className="flex items-center gap-3">
            {i > 0 && <span className="text-[var(--color-fg-quaternary)]">·</span>}
            <button
              onClick={() => setMode(m)}
              className={
                mode === m
                  ? 'text-[var(--color-accent)]'
                  : 'text-[var(--color-fg-tertiary)] hover:text-[var(--color-fg)]'
              }
            >
              {m === 'new' ? 'New' : m === 'open' ? 'Open' : 'Clone'}
            </button>
          </span>
        ))}
      </div>

      <div className="mt-10 space-y-6">
        {mode === 'clone' && (
          <Field
            label="Remote URL"
            value={remote}
            onChange={(e) => setRemote(e.target.value)}
            placeholder="https://github.com/you/paper.git"
          />
        )}
        {mode !== 'clone' && (
          <Field
            label="Name"
            value={name}
            onChange={(e) => setName(e.target.value)}
            placeholder="my-paper"
          />
        )}
        <div>
          <label className="block uppercase tracking-widest text-[var(--color-fg-tertiary)] font-mono text-[10px] mb-2">
            Location
          </label>
          <div className="flex items-center justify-between border-b border-[var(--color-border)] py-2">
            <span className="font-mono text-sm text-[var(--color-fg)] truncate">
              {path || <span className="text-[var(--color-fg-tertiary)]">No folder selected</span>}
            </span>
            <button
              onClick={pickFolder}
              className="font-mono text-sm text-[var(--color-accent)] hover:opacity-70"
            >
              Choose...
            </button>
          </div>
        </div>
      </div>

      {error && <p className="mt-4 text-xs text-red-500 font-mono">{error}</p>}

      <div className="mt-12 flex justify-end">
        <Button variant="primary" disabled={!valid || busy} onClick={handleDone}>
          {busy ? 'Working...' : 'Done'}
        </Button>
      </div>
    </div>
  );
}
