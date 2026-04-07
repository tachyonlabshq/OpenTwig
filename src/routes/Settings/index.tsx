import { useEffect, useState } from 'react';
import Button from '../../components/Button';
import Field from '../../components/Field';
import { tauri, GitServer, safeInvoke } from '../../lib/tauri';
import { useStore } from '../../store';

type Tab = 'general' | 'servers' | 'ai' | 'account';

const TABS: { id: Tab; label: string }[] = [
  { id: 'general', label: 'General' },
  { id: 'servers', label: 'Git Servers' },
  { id: 'ai', label: 'AI' },
  { id: 'account', label: 'Account' },
];

export default function Settings() {
  const [tab, setTab] = useState<Tab>('general');

  return (
    <div className="h-full flex">
      <div className="w-44 border-r border-[var(--color-border)] py-6 px-4">
        {TABS.map((t) => (
          <button
            key={t.id}
            onClick={() => setTab(t.id)}
            className={`block w-full text-left py-1.5 font-mono text-xs ${
              tab === t.id
                ? 'text-[var(--color-accent)]'
                : 'text-[var(--color-fg-secondary)] hover:text-[var(--color-fg)]'
            }`}
          >
            {t.label}
          </button>
        ))}
      </div>
      <div className="flex-1 overflow-y-auto p-10 max-w-2xl">
        {tab === 'general' && <General />}
        {tab === 'servers' && <Servers />}
        {tab === 'ai' && <AI />}
        {tab === 'account' && <Account />}
      </div>
    </div>
  );
}

function General() {
  const reset = useStore((s) => s.resetOnboarding);
  return (
    <div>
      <h3 className="font-mono text-base text-[var(--color-fg)]">General</h3>
      <p className="mt-1 text-xs text-[var(--color-fg-tertiary)] font-sans">
        Application preferences.
      </p>
      <div className="mt-10">
        <Button variant="secondary" onClick={reset}>
          Reset Onboarding
        </Button>
      </div>
    </div>
  );
}

function Servers() {
  const [servers, setServers] = useState<GitServer[]>([]);
  const [adding, setAdding] = useState(false);
  const [newName, setNewName] = useState('');
  const [newBase, setNewBase] = useState('');
  const [newWeb, setNewWeb] = useState('');
  const [newToken, setNewToken] = useState('');

  async function refresh() {
    setServers(await safeInvoke(() => tauri.gitServer.list(), [] as GitServer[]));
  }
  useEffect(() => {
    refresh();
  }, []);

  async function add() {
    await safeInvoke(
      () =>
        tauri.gitServer.add({
          kind: 'custom',
          displayName: newName,
          baseUrl: newBase,
          webUrl: newWeb,
          authMethod: 'token',
          token: newToken || undefined,
        }),
      null,
    );
    setAdding(false);
    setNewName('');
    setNewBase('');
    setNewWeb('');
    setNewToken('');
    refresh();
  }

  async function remove(id: string) {
    await safeInvoke(() => tauri.gitServer.delete(id), undefined);
    refresh();
  }

  return (
    <div>
      <div className="flex items-center justify-between">
        <div>
          <h3 className="font-mono text-base text-[var(--color-fg)]">Git Servers</h3>
          <p className="mt-1 text-xs text-[var(--color-fg-tertiary)] font-sans">
            Servers your projects can sync to.
          </p>
        </div>
        <Button variant="primary" onClick={() => setAdding((a) => !a)}>
          {adding ? 'Cancel' : 'Add Server'}
        </Button>
      </div>

      <div className="mt-8 space-y-4">
        {servers.length === 0 && !adding && (
          <p className="text-xs text-[var(--color-fg-tertiary)] font-mono">No servers configured.</p>
        )}
        {servers.map((s) => (
          <div
            key={s.id}
            className="flex items-center justify-between py-3 border-b border-[var(--color-border)]"
          >
            <div>
              <div className="font-mono text-sm text-[var(--color-fg)]">{s.display_name}</div>
              <div className="font-mono text-[10px] text-[var(--color-fg-tertiary)]">{s.base_url}</div>
            </div>
            <button
              onClick={() => remove(s.id)}
              className="font-mono text-xs text-[var(--color-fg-secondary)] hover:text-red-500"
            >
              Remove
            </button>
          </div>
        ))}
      </div>

      {adding && (
        <div className="mt-8 space-y-6 border-t border-[var(--color-border)] pt-8">
          <Field label="Display Name" value={newName} onChange={(e) => setNewName(e.target.value)} />
          <Field label="API Base URL" value={newBase} onChange={(e) => setNewBase(e.target.value)} />
          <Field label="Web URL" value={newWeb} onChange={(e) => setNewWeb(e.target.value)} />
          <Field
            label="Token"
            type="password"
            value={newToken}
            onChange={(e) => setNewToken(e.target.value)}
            caption="Stored in your system keyring."
          />
          <div className="flex justify-end">
            <Button variant="primary" onClick={add} disabled={!newName || !newBase}>
              Save
            </Button>
          </div>
        </div>
      )}
    </div>
  );
}

function AI() {
  const [key, setKey] = useState('');
  const [hasKey, setHasKey] = useState(false);

  useEffect(() => {
    safeInvoke(() => tauri.ai.hasKey(), false).then(setHasKey);
  }, []);

  async function save() {
    await safeInvoke(() => tauri.ai.saveKey(key), undefined);
    setKey('');
    setHasKey(true);
  }

  return (
    <div>
      <h3 className="font-mono text-base text-[var(--color-fg)]">AI</h3>
      <p className="mt-1 text-xs text-[var(--color-fg-tertiary)] font-sans">
        {hasKey ? 'API key configured.' : 'No API key configured.'}
      </p>
      <div className="mt-10 space-y-6">
        <Field
          label="Anthropic API Key"
          type="password"
          value={key}
          onChange={(e) => setKey(e.target.value)}
          caption="Stored in your system keyring."
        />
        <div className="flex justify-end">
          <Button variant="primary" onClick={save} disabled={!key}>
            Save
          </Button>
        </div>
      </div>
    </div>
  );
}

function Account() {
  const name = useStore((s) => s.authorName);
  const email = useStore((s) => s.authorEmail);
  const setAuthor = useStore((s) => s.setAuthor);
  const [n, setN] = useState(name);
  const [e, setE] = useState(email);
  return (
    <div>
      <h3 className="font-mono text-base text-[var(--color-fg)]">Account</h3>
      <p className="mt-1 text-xs text-[var(--color-fg-tertiary)] font-sans">
        Your commit identity.
      </p>
      <div className="mt-10 space-y-6">
        <Field label="Name" value={n} onChange={(ev) => setN(ev.target.value)} />
        <Field label="Email" value={e} onChange={(ev) => setE(ev.target.value)} />
        <div className="flex justify-end">
          <Button variant="primary" onClick={() => setAuthor(n, e)}>
            Save
          </Button>
        </div>
      </div>
    </div>
  );
}
