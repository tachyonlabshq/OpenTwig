import { useState } from 'react';
import Button from '../../components/Button';
import Field from '../../components/Field';

export interface PickedServer {
  kind: string;
  displayName: string;
  baseUrl: string;
  webUrl: string;
}

interface PresetRow {
  id: string;
  kind: string;
  displayName: string;
  baseUrl: string;
  webUrl: string;
  custom?: boolean;
}

const PRESETS: PresetRow[] = [
  { id: 'github', kind: 'github', displayName: 'GitHub', baseUrl: 'https://api.github.com', webUrl: 'https://github.com' },
  { id: 'gitlab', kind: 'gitlab', displayName: 'GitLab', baseUrl: 'https://gitlab.com/api/v4', webUrl: 'https://gitlab.com' },
  { id: 'codeberg', kind: 'gitea', displayName: 'Codeberg', baseUrl: 'https://codeberg.org/api/v1', webUrl: 'https://codeberg.org' },
  { id: 'bitbucket', kind: 'bitbucket', displayName: 'Bitbucket', baseUrl: 'https://api.bitbucket.org/2.0', webUrl: 'https://bitbucket.org' },
  { id: 'gitea', kind: 'gitea', displayName: 'Self-hosted (Gitea)', baseUrl: '', webUrl: '', custom: true },
  { id: 'custom', kind: 'custom', displayName: 'Custom...', baseUrl: '', webUrl: '', custom: true },
];

export default function ServerPicker({ onNext }: { onNext: (s: PickedServer) => void }) {
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const [baseUrl, setBaseUrl] = useState('');
  const [webUrl, setWebUrl] = useState('');

  const selected = PRESETS.find((p) => p.id === selectedId) ?? null;
  const isCustom = !!selected?.custom;
  const valid = !!selected && (!isCustom || (baseUrl.trim() && webUrl.trim()));

  function handleNext() {
    if (!selected) return;
    onNext({
      kind: selected.kind,
      displayName: selected.displayName,
      baseUrl: isCustom ? baseUrl.trim() : selected.baseUrl,
      webUrl: isCustom ? webUrl.trim() : selected.webUrl,
    });
  }

  return (
    <div>
      <h2 className="font-mono text-2xl text-[var(--color-fg)]">Where do you host?</h2>
      <p className="mt-2 text-sm text-[var(--color-fg-tertiary)] font-sans">
        You can add more servers later.
      </p>
      <div className="mt-10 space-y-1">
        {PRESETS.map((p) => {
          const isSel = p.id === selectedId;
          return (
            <button
              key={p.id}
              onClick={() => setSelectedId(p.id)}
              className={`group flex items-center w-full text-left py-2 font-mono text-sm transition-colors ${
                isSel ? 'text-[var(--color-accent)]' : 'text-[var(--color-fg)] hover:text-[var(--color-fg-secondary)]'
              }`}
            >
              <span className={`inline-block w-3 mr-1 ${isSel ? 'opacity-100' : 'opacity-0'}`}>·</span>
              {p.displayName}
            </button>
          );
        })}
      </div>
      {isCustom && (
        <div className="mt-6 space-y-6">
          <Field
            label="API Base URL"
            value={baseUrl}
            onChange={(e) => setBaseUrl(e.target.value)}
            placeholder="https://git.example.com/api/v1"
          />
          <Field
            label="Web URL"
            value={webUrl}
            onChange={(e) => setWebUrl(e.target.value)}
            placeholder="https://git.example.com"
          />
        </div>
      )}
      <div className="mt-12 flex justify-end">
        <Button variant="primary" disabled={!valid} onClick={handleNext}>
          Continue
        </Button>
      </div>
    </div>
  );
}
