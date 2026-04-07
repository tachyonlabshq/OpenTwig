import { GitBranch, GitCommit, ArrowUpFromLine, ArrowDownToLine, FileText, BookMarked, Clock, Settings as SettingsIcon, Plus, Search } from 'lucide-react';

const SAMPLE_DOC = `---
title: "CRDT-Based Collaborative Editing in Academic Workflows"
author: Michael Wong
date: 2026-04-07
---

# Introduction

Real-time collaboration on scholarly prose remains an unsolved problem at
the intersection of version control and editorial workflow. While tools
like Overleaf offer operational transformation for live editing, they
sidestep Git entirely — leaving researchers without branching, attribution,
or auditable history [@nichols2023].

This paper proposes a hybrid architecture where Yjs CRDTs handle live
edits within active sessions, while Git remains the canonical store between
sessions. The bridge is a sync service that serializes Yjs state to
semantic-line-broken Markdown on commit.

## Background

Manubot [@himmelstein2019] demonstrated that Git-backed academic writing
is viable, but its workflow demands command-line fluency. Curvenote
introduced block-level versioning with MyST, yet abandoned Git as the
substrate. No prior work bridges the accessibility gap.

## Method

We extend the Pandoc-flavored Markdown standard with three additions:

1. **Semantic line breaks** — one sentence per line, enabling per-sentence
   git blame and clean three-way merges.
2. **Citation provenance** — each \`@citekey\` is diffed against
   \`references.json\` post-commit to detect orphaned or fabricated
   references.
3. **AI-assisted merge resolution** — conflict regions are resolved by
   a separate read-only worker that calls Claude with surrounding
   context, never auto-applying changes.
`;

const SAMPLE_DOCS = [
  { name: 'paper.md', path: 'src/paper.md', words: 1247, modified: true },
  { name: 'abstract.md', path: 'src/abstract.md', words: 234, modified: false },
  { name: 'references.json', path: 'bib/references.json', words: 89, modified: false },
  { name: 'methodology.md', path: 'src/methodology.md', words: 891, modified: false },
  { name: 'related-work.md', path: 'src/related-work.md', words: 612, modified: false },
];

export default function DemoView() {
  const lines = SAMPLE_DOC.split('\n');

  return (
    <div className="h-screen flex flex-col bg-bg text-fg overflow-hidden">
      {/* Top toolbar */}
      <div className="h-11 border-b border-border flex items-center px-4 gap-3 shrink-0">
        <div className="flex items-center gap-2">
          <span className="text-sm font-medium">CRDT Academic Workflows</span>
          <span className="text-fg-tertiary text-xs">·</span>
          <span className="text-fg-secondary text-xs flex items-center gap-1">
            <GitBranch size={11} /> main
          </span>
        </div>
        <div className="flex-1" />
        <button className="p-1.5 hover:bg-border/50 rounded text-fg-secondary" title="Commit">
          <GitCommit size={15} />
        </button>
        <button className="p-1.5 hover:bg-border/50 rounded text-fg-secondary" title="Push">
          <ArrowUpFromLine size={15} />
        </button>
        <button className="p-1.5 hover:bg-border/50 rounded text-fg-secondary" title="Pull">
          <ArrowDownToLine size={15} />
        </button>
      </div>

      <div className="flex-1 flex overflow-hidden">
        {/* Sidebar */}
        <aside className="w-[220px] border-r border-border flex flex-col shrink-0">
          <div className="px-4 py-3 border-b border-border">
            <div className="text-fg-tertiary text-[10px] font-mono tracking-widest mb-1">PROJECT</div>
            <div className="text-sm font-medium truncate">CRDT Academic Workflows</div>
            <div className="text-fg-tertiary text-xs mt-0.5">github · main</div>
          </div>

          <nav className="px-2 py-3 flex-1">
            <div className="text-fg-tertiary text-[10px] font-mono tracking-widest px-2 mb-2">WORKSPACE</div>
            <NavItem icon={<FileText size={14} />} label="Documents" active />
            <NavItem icon={<GitBranch size={14} />} label="Branches" badge="3" />
            <NavItem icon={<BookMarked size={14} />} label="Citations" badge="42" />
            <NavItem icon={<Clock size={14} />} label="Activity" />
            <NavItem icon={<SettingsIcon size={14} />} label="Settings" />
          </nav>

          <div className="px-4 py-3 border-t border-border flex items-center gap-2">
            <span className="w-1.5 h-1.5 rounded-full bg-emerald-500"></span>
            <span className="text-fg-secondary text-xs">Up to date</span>
          </div>
        </aside>

        {/* Document list */}
        <div className="w-[280px] border-r border-border flex flex-col shrink-0">
          <div className="h-11 border-b border-border flex items-center px-4 gap-2">
            <span className="text-sm font-medium flex-1">Documents</span>
            <button className="p-1 text-fg-tertiary hover:text-fg-secondary"><Search size={13} /></button>
            <button className="p-1 text-fg-tertiary hover:text-fg-secondary"><Plus size={14} /></button>
          </div>
          <div className="flex-1 overflow-y-auto">
            {SAMPLE_DOCS.map((d, i) => (
              <div
                key={d.path}
                className={`px-4 py-2.5 border-b border-border/40 cursor-pointer ${i === 0 ? 'bg-border/30' : 'hover:bg-border/20'}`}
              >
                <div className="flex items-center gap-2">
                  <span className="text-sm font-mono truncate flex-1">{d.name}</span>
                  {d.modified && <span className="w-1.5 h-1.5 rounded-full bg-accent shrink-0"></span>}
                </div>
                <div className="flex items-center justify-between mt-0.5">
                  <span className="text-fg-tertiary text-[11px] truncate">{d.path}</span>
                  <span className="text-fg-tertiary text-[10px] font-mono ml-2 shrink-0">{d.words}w</span>
                </div>
              </div>
            ))}
          </div>
        </div>

        {/* Editor */}
        <div className="flex-1 flex flex-col overflow-hidden">
          <div className="flex-1 overflow-y-auto flex">
            {/* Line gutter */}
            <div className="w-12 shrink-0 py-6 text-right pr-3 select-none">
              {lines.map((_, i) => (
                <div key={i} className="text-fg-quaternary text-[11px] font-mono leading-6">{i + 1}</div>
              ))}
            </div>
            {/* Code area */}
            <pre className="flex-1 py-6 pr-8 font-mono text-[13px] leading-6 text-fg whitespace-pre-wrap">
              {lines.map((line, i) => {
                let cls = '';
                if (line.startsWith('# ')) cls = 'text-fg font-semibold';
                else if (line.startsWith('## ')) cls = 'text-fg font-semibold';
                else if (line.startsWith('---')) cls = 'text-fg-quaternary';
                else if (line.match(/^(title|author|date):/)) cls = 'text-fg-tertiary';
                else if (line.match(/\[@\w+\]/)) cls = '';
                return (
                  <div key={i} className={cls}>
                    {highlightCitations(line)}
                  </div>
                );
              })}
            </pre>
          </div>
          {/* Status bar */}
          <div className="h-7 border-t border-border flex items-center px-4 gap-3 text-fg-tertiary text-[11px] font-mono shrink-0">
            <span>1,247 words</span>
            <span>·</span>
            <span>7,834 chars</span>
            <span>·</span>
            <span>Ln 8, Col 1</span>
            <div className="flex-1" />
            <span className="flex items-center gap-1.5">
              <span className="w-1.5 h-1.5 rounded-full bg-accent"></span>
              Modified
            </span>
          </div>
        </div>
      </div>
    </div>
  );
}

function NavItem({ icon, label, active, badge }: { icon: React.ReactNode; label: string; active?: boolean; badge?: string }) {
  return (
    <div className={`flex items-center gap-2 px-2 py-1.5 rounded text-sm cursor-pointer ${active ? 'bg-border/60 text-fg' : 'text-fg-secondary hover:bg-border/30'}`}>
      <span className={active ? 'text-accent' : ''}>{icon}</span>
      <span className="flex-1">{label}</span>
      {badge && <span className="text-fg-tertiary text-[10px] font-mono">{badge}</span>}
    </div>
  );
}

function highlightCitations(line: string) {
  const parts = line.split(/(\[@[\w-]+\])/);
  return parts.map((p, i) =>
    p.match(/^\[@/) ? (
      <span key={i} className="text-accent">{p}</span>
    ) : (
      <span key={i}>{p}</span>
    ),
  );
}
