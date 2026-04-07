import { useEffect, useMemo, useRef, useState } from 'react';
import { tauri, DocumentEntry, safeInvoke } from '../../lib/tauri';

export default function Editor({ doc }: { doc: DocumentEntry | null }) {
  const [content, setContent] = useState('');
  const [cursor, setCursor] = useState({ ln: 1, col: 1 });
  const taRef = useRef<HTMLTextAreaElement>(null);
  const saveTimer = useRef<number | null>(null);

  useEffect(() => {
    if (!doc) {
      setContent('');
      return;
    }
    safeInvoke(() => tauri.document.read(doc.path), '').then(setContent);
  }, [doc?.path]);

  useEffect(() => {
    if (!doc) return;
    if (saveTimer.current) window.clearTimeout(saveTimer.current);
    saveTimer.current = window.setTimeout(() => {
      safeInvoke(() => tauri.document.write(doc.path, content), undefined);
    }, 500);
    return () => {
      if (saveTimer.current) window.clearTimeout(saveTimer.current);
    };
  }, [content, doc?.path]);

  const lines = useMemo(() => content.split('\n'), [content]);
  const wordCount = useMemo(
    () => content.trim().split(/\s+/).filter(Boolean).length,
    [content],
  );

  function updateCursor() {
    const el = taRef.current;
    if (!el) return;
    const pos = el.selectionStart;
    const before = content.slice(0, pos);
    const ln = before.split('\n').length;
    const col = pos - before.lastIndexOf('\n');
    setCursor({ ln, col });
  }

  if (!doc) {
    return (
      <div className="h-full flex items-center justify-center text-[var(--color-fg-tertiary)] font-mono text-xs">
        No document selected.
      </div>
    );
  }

  return (
    <div className="h-full flex flex-col">
      <div className="flex-1 flex min-h-0 overflow-auto">
        <div className="select-none pl-4 pr-3 py-6 font-mono text-xs text-[var(--color-fg-quaternary)] text-right leading-6">
          {lines.map((_, i) => (
            <div key={i}>{i + 1}</div>
          ))}
        </div>
        <textarea
          ref={taRef}
          value={content}
          onChange={(e) => setContent(e.target.value)}
          onKeyUp={updateCursor}
          onClick={updateCursor}
          spellCheck={false}
          className="flex-1 resize-none py-6 pr-8 font-mono text-sm leading-6 text-[var(--color-fg)]"
        />
      </div>
      <div className="h-7 px-4 flex items-center justify-between border-t border-[var(--color-border)] font-mono text-[10px] text-[var(--color-fg-tertiary)]">
        <span>{doc.name}</span>
        <div className="flex items-center gap-4">
          <span>{wordCount} words</span>
          <span>{content.length} chars</span>
          <span>
            Ln {cursor.ln}, Col {cursor.col}
          </span>
        </div>
      </div>
    </div>
  );
}
