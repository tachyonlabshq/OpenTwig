import { useState } from 'react';
import Field from '../../components/Field';
import Button from '../../components/Button';
import { useStore } from '../../store';

export default function Identity({ onNext }: { onNext: () => void }) {
  const setAuthor = useStore((s) => s.setAuthor);
  const [name, setName] = useState(useStore.getState().authorName);
  const [email, setEmail] = useState(useStore.getState().authorEmail);

  const valid = name.trim().length > 0 && email.trim().includes('@');

  function handleNext() {
    setAuthor(name.trim(), email.trim());
    onNext();
  }

  return (
    <div>
      <h2 className="font-mono text-2xl text-[var(--color-fg)]">Who are you?</h2>
      <p className="mt-2 text-sm text-[var(--color-fg-tertiary)] font-sans">
        These appear on your commits.
      </p>
      <div className="mt-10 space-y-6">
        <Field
          label="Name"
          value={name}
          onChange={(e) => setName(e.target.value)}
          autoFocus
          placeholder="Ada Lovelace"
        />
        <Field
          label="Email"
          type="email"
          value={email}
          onChange={(e) => setEmail(e.target.value)}
          placeholder="ada@example.org"
        />
      </div>
      <div className="mt-12 flex justify-end">
        <Button variant="primary" disabled={!valid} onClick={handleNext}>
          Continue
        </Button>
      </div>
    </div>
  );
}
