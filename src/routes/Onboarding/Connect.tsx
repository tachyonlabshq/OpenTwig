import { useState } from 'react';
import Field from '../../components/Field';
import Button from '../../components/Button';
import { tauri } from '../../lib/tauri';
import { PickedServer } from './ServerPicker';

interface Props {
  server: PickedServer;
  onDone: (serverId: string) => void;
  onBack: () => void;
}

export default function Connect({ server, onDone, onBack }: Props) {
  const [token, setToken] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function handle(useToken: boolean) {
    setBusy(true);
    setError(null);
    try {
      const result = await tauri.gitServer.add({
        kind: server.kind,
        displayName: server.displayName,
        baseUrl: server.baseUrl,
        webUrl: server.webUrl,
        authMethod: useToken ? 'token' : 'ssh',
        token: useToken ? token.trim() : undefined,
      });
      onDone(result.id);
    } catch (e: any) {
      setError(String(e?.message ?? e));
    } finally {
      setBusy(false);
    }
  }

  return (
    <div>
      <h2 className="font-mono text-2xl text-[var(--color-fg)]">Connect</h2>
      <p className="mt-2 text-sm text-[var(--color-fg-tertiary)] font-sans">
        {server.displayName}
      </p>
      <div className="mt-10">
        <Field
          label="Personal Access Token"
          type="password"
          value={token}
          onChange={(e) => setToken(e.target.value)}
          autoFocus
          placeholder="ghp_xxxxxxxxxxxx"
          caption="Stored in your system keyring."
        />
      </div>
      {error && (
        <p className="mt-4 text-xs text-red-500 font-mono">{error}</p>
      )}
      <div className="mt-12 flex items-center justify-between">
        <Button variant="secondary" onClick={onBack} disabled={busy}>
          Back
        </Button>
        <div className="flex items-center gap-6">
          <Button variant="secondary" onClick={() => handle(false)} disabled={busy}>
            Skip
          </Button>
          <Button variant="primary" onClick={() => handle(true)} disabled={busy || !token.trim()}>
            Continue
          </Button>
        </div>
      </div>
    </div>
  );
}
