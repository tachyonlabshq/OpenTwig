# Git-backed academic collaboration platform: full technical architecture

**No existing tool combines Git-native version control, AI-assisted merge resolution, and a researcher-friendly UI for academic writing.** This gap represents a significant opportunity. After analyzing 12+ competing tools, the GitHub API surface, CRDT collaboration patterns, Tauri desktop architecture, Claude API capabilities, and citation processing ecosystems, this document provides the complete architecture for building this platform. The core differentiator — AI-powered prose merge conflict resolution — is genuinely unsolved; every competitor either avoids merges entirely (Overleaf's real-time OT) or leaves them painfully manual (Manubot's raw Git workflow).

---

## The competitive landscape has one massive blind spot

Across the 12 tools analyzed — Overleaf, Manubot, Authorea, Manuscripts.io, Curvenote, Fidus Writer, HackMD, Quarto, Typst, and raw GitHub/GitLab — **zero offer AI-assisted merge conflict resolution for scholarly prose**. AI merge tools exist for code (GitKraken AI, GitHub Copilot, MergeBERT), but academic text is fundamentally different: it requires understanding argument structure, citation integrity, and disciplinary conventions.

The landscape splits into two camps that never meet. **User-friendly tools** (Overleaf with 20M+ users, Authorea, Typst) provide real-time collaborative editing but hide or minimize Git, offer only binary View/Edit permissions, and lack branching workflows. **Git-native tools** (Manubot, Quarto, raw GitHub) provide full version control but demand command-line fluency that excludes most researchers. No tool bridges this divide.

Five specific gaps define the opportunity:

- **AI prose merging**: When two researchers edit the same paragraph on different branches, no tool intelligently suggests how to combine their changes. Overleaf sidesteps the problem via real-time OT; Manubot leaves merge conflicts entirely to the user.
- **Version-tracked citations**: No platform treats citation changes as first-class reviewable events. Citation additions and removals are buried in text diffs rather than surfaced distinctly.
- **Scholarly role mapping**: Overleaf offers only View/Edit. Manubot inherits GitHub's developer-oriented roles. No tool maps academic roles (PI, Lead Author, Contributing Author) to permission levels.
- **Cross-format authoring**: Overleaf is LaTeX-only. Manubot is Markdown-only. Researchers across disciplines have incompatible format preferences (physics→LaTeX, biology→Word, CS→Markdown).
- **Git-native with accessible UI**: Making branching feel like "Create a draft revision" and merging feel like "Accept these changes" would be transformative for non-technical academics.

Manubot comes closest to this vision: fully Git-native, open-source, with an experimental AI Editor that generates paragraph-level revisions as PRs. But it requires deep GitHub fluency and offers no WYSIWYG editing. Curvenote innovates with block-level versioning and MyST Markdown but isn't Git-native at its core. Typst (45K GitHub stars) is rapidly growing as a LaTeX alternative but lacks track changes entirely.

---

## Recommended tech stack with architectural rationale

Every major technical decision flows from two constraints: Git as the source of truth for documents, and the requirement that AI never auto-applies changes.

### Document format and conversion layer

**Pandoc-flavored Markdown** should be the canonical storage format. It provides the cleanest Git diffs, broadest accessibility, and Pandoc's reader→AST→writer pipeline enables conversion to LaTeX, DOCX, HTML, and PDF. Pandoc's AST (`Pandoc Meta [Block]`) represents documents as typed trees of blocks (paragraphs, headers, code blocks) and inlines (text, emphasis, citations, math), making it possible to build format-agnostic tooling.

For Git diffability, enforce the **semantic line breaks** convention: one sentence per line, with optional breaks at clause boundaries. This ensures `git diff` shows exactly which sentences changed, `git blame` attributes authorship per-sentence, and merge conflicts are localized. The `sembr` Python package can auto-insert these breaks.

Store binary assets (figures, PDFs) via **Git LFS** with `.gitattributes` routing:
```
*.pdf filter=lfs diff=lfs merge=lfs -text
*.png filter=lfs diff=lfs merge=lfs -text
*.md text
*.bib text
*.json text
```

**Recommended repository structure** for each project:
```
paper-repo/
├── src/                  # Manuscript source files (.md)
├── bib/
│   ├── references.json   # CSL JSON (canonical bibliography)
│   └── style.csl         # Citation style
├── figures/              # Git LFS for raster, tracked for SVG
├── templates/            # LaTeX/DOCX templates
├── metadata.yaml         # Pandoc metadata (title, authors)
└── .github/
    └── CODEOWNERS        # Maintainer review requirements
```

### Frontend and desktop architecture

A **monorepo** with three packages — `shared` (React components, hooks, types), `web` (browser app via Vite), and `desktop` (Tauri 2.x wrapper) — enables maximum code reuse. Tauri 2.x uses the OS-native WebView rather than bundling Chromium, yielding **3–10 MB app bundles** versus Electron's 80–244 MB, with ~30–50 MB RAM at idle versus Electron's 100–300 MB.

The critical architectural pattern is a **platform abstraction layer** that checks `window.__TAURI__` at runtime and routes to either Tauri `invoke()` calls or REST API calls:

```typescript
export const isTauri = typeof window !== 'undefined' && '__TAURI__' in window;

export async function commitDocument(path: string, content: string) {
  if (isTauri) {
    return invoke('git_commit', { path, content });
  } else {
    return fetch('/api/git/commit', { method: 'POST', body: JSON.stringify({ path, content }) });
  }
}
```

Tauri's Rust backend handles Git operations via the **git2-rs crate** (libgit2 bindings), which supports clone, commit, push, pull, branch, merge, and diff without requiring Git CLI installation. Authentication uses the **auth-git2 crate** for SSH agent + HTTPS token handling, with tokens stored encrypted via `tauri-plugin-stronghold`. For long-running operations (clone, push), Tauri's **Channel API** streams progress to the frontend without blocking the UI.

### GitHub integration layer

Use a **GitHub App** (not OAuth App) for all GitHub operations. GitHub Apps provide fine-grained permissions (request only "Contents: Read/Write" instead of the broad `repo` scope), per-repository access selection, short-lived tokens (1-hour installation tokens, 8-hour user tokens with refresh), and built-in centralized webhooks. Rate limits scale with repository count: **5,000 requests/hour minimum**, increasing by 50/hr per repo above 20.

For committing files, the **GraphQL `createCommitOnBranch` mutation** is the recommended approach — a single API call commits multiple file additions, modifications, and deletions with author attribution, replacing the 4–6 sequential REST calls required by the Git Data API. The `expectedHeadOid` parameter prevents race conditions.

Use **Octokit.js** (`@octokit/core` + `@octokit/auth-app`) for the web/Node.js backend and **Octocrab** for Rust-side operations in the Tauri desktop app. Both support REST and GraphQL. Octocrab's semantic API covers pulls, repos, issues, and commits with a builder pattern, falling back to raw HTTP for uncovered endpoints.

### Backend infrastructure

**Supabase** (PostgreSQL + Row Level Security + Realtime + Auth) handles all metadata that lives outside Git: user profiles, project roles, AI suggestion queues, activity logs, citation libraries, and comments. Supabase's real-time subscriptions push database changes to connected clients via WebSocket, enabling instant UI updates when comments are added or AI suggestions complete.

---

## High-level system architecture

```
┌────────────────────────────────────────────────────────────────┐
│                        CLIENT LAYER                             │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────────┐ │
│  │  Web App      │  │  Tauri App   │  │  Shared React +      │ │
│  │  (Browser)    │  │  (Desktop)   │  │  TipTap/ProseMirror  │ │
│  │  REST/WS ↕    │  │  IPC ↕ Rust  │  │  + Yjs CRDT          │ │
│  └──────┬───────┘  └──────┬───────┘  └──────────────────────┘ │
└─────────┼──────────────────┼───────────────────────────────────┘
          │                  │
┌─────────▼──────────────────▼───────────────────────────────────┐
│                      SERVER LAYER                               │
│  ┌────────────────┐  ┌────────────────┐  ┌──────────────────┐ │
│  │ API Server     │  │ y-websocket    │  │ Webhook Handler  │ │
│  │ (Node.js)      │  │ (Yjs Collab)   │  │ (GitHub events)  │ │
│  └───────┬────────┘  └───────┬────────┘  └───────┬──────────┘ │
│          │                   │                    │            │
│  ┌───────▼───────────────────▼────────────────────▼──────────┐ │
│  │                    SERVICE LAYER                            │ │
│  │  ┌──────────┐  ┌──────────────┐  ┌─────────────────────┐ │ │
│  │  │ Git Sync │  │ AI Merge     │  │ Citation Processor  │ │ │
│  │  │ Service  │  │ Worker       │  │ (Citation.js +      │ │ │
│  │  │          │  │ (Claude API) │  │  citeproc-js)       │ │ │
│  │  └────┬─────┘  └──────┬──────┘  └──────────┬──────────┘ │ │
│  └───────┼───────────────┼──────────────────────┼────────────┘ │
│          │               │                      │              │
│  ┌───────▼───────┐  ┌───▼──────────┐  ┌───────▼────────────┐ │
│  │ GitHub API    │  │ BullMQ Queue │  │ Supabase           │ │
│  │ (Octokit.js)  │  │ (Redis)      │  │ (Postgres + RLS +  │ │
│  └───────────────┘  └──────────────┘  │  Realtime)         │ │
│                                        └────────────────────┘ │
└────────────────────────────────────────────────────────────────┘
```

The **Git Sync Service** bridges the CRDT collaboration layer and GitHub. During active editing sessions, Yjs handles real-time CRDT synchronization via WebSocket; the server periodically serializes Yjs document state to plain text, commits to the local Git repository, and pushes to GitHub. When no active session exists, GitHub is the canonical source — external changes (merged PRs, direct pushes) are pulled, converted to Yjs state, and propagated to reconnecting clients.

The **AI Merge Worker** operates as a completely separate process with **read-only access** to repositories. It receives jobs from a BullMQ queue (triggered by GitHub webhooks on PR events), reads diffs and comments, calls Claude, and writes proposed resolutions to Supabase's `ai_suggestions` table. A separate "apply" pathway — triggered only by authenticated human action — has write access to create commits. This architectural separation enforces the human-in-the-loop requirement at the infrastructure level.

---

## Data models for documents, citations, versions, and permissions

### Core database schema (Supabase/PostgreSQL)

The schema splits into six domain areas. **Users** link to GitHub identities with encrypted token storage. **Projects** map 1:1 to GitHub repositories with cached metadata. **Project Members** implement the four-tier role system (owner, maintainer, contributor, viewer) with Row Level Security enforcing access at the database level. **AI Suggestions** track every proposal with its status lifecycle (pending → accepted/rejected → applied). **Citations** support both per-project shared libraries and per-user personal libraries. **Activity Log** provides the full audit trail.

The permission model uses a **dual-layer** approach: GitHub branch protection rules require PR reviews from CODEOWNERS-designated maintainers for the `main` branch, while Supabase RLS policies enforce app-level role checks before any GitHub API call is proxied. This means even if a user has Write access on GitHub, the app can enforce that contributors may only create branches and comment — never merge to main. The app's installation token (bot identity) mediates all merges, ensuring the permission gateway cannot be bypassed.

### Citation version tracking model

Citations use **CSL JSON** as the canonical interchange format, stored as `references.json` in the repository. This format is natively supported by Zotero, Mendeley, Pandoc, Citation.js, and citeproc-js. Inline references in Markdown use Pandoc's `@citekey` syntax (e.g., `@smith2024`), which is plain text and diffs cleanly.

Tracking "who cited what, when" requires no special infrastructure beyond Git itself. `git blame references.json` reveals who added each bibliography entry and when. `git blame document.md` shows who wrote the line containing each `@citekey`. For richer citation analytics, a post-commit hook or CI job can extract all `@citekey` references, cross-reference them against `references.json`, and write a citation provenance manifest to the app database. Diffing `references.json` between any two commits reveals exactly which citations were added, removed, or modified.

Citation processing uses **Citation.js** (modular, browser + Node.js, supports BibTeX/DOI/RIS/CSL JSON input) for format conversion and **citeproc-js** (the same CSL processor used by Zotero and Mendeley, 9,500+ styles from the CSL repository) for rendering formatted bibliographies. Pandoc's built-in `--citeproc` flag handles document compilation. Import from Zotero uses its Web API v3 (`?format=csljson`), from Mendeley via BibTeX export.

---

## AI merge assistant: architecture and prompt engineering

### Processing pipeline

When a GitHub webhook fires for a PR event (creation, new commits, new review comments), the webhook handler enqueues a job in BullMQ with a **30-second debounce** — if additional events arrive within that window, the timer resets to avoid redundant AI runs during active review discussions. The job is deduplicated by hashing `PR_number + HEAD_SHA + comment_count`.

The AI Merge Worker executes this pipeline for each job:

1. **Collect context**: Fetch the three-way merge data — base version (`git show :1:file`), ours (`git show :2:file`), theirs (`git show :3:file`). Collect all PR comments via GitHub API (issue comments, inline review comments, review-level comments). Extract commit messages from both branches since divergence.
2. **Parse conflicts**: Extract conflict regions using diff3-style markers (enabled via `git config merge.conflictstyle diff3`), which include the base version for each conflict — critical for AI understanding of what changed.
3. **Call Claude**: Use **Claude Sonnet 4.6** ($3/$15 per 1M tokens, 1M context window at standard pricing) with structured outputs guaranteeing a parseable JSON response matching the `MergeResult` schema. Each conflict gets base/ours/theirs text, surrounding context (±100 lines), attributed reviewer comments, and commit messages.
4. **Validate**: Post-processing checks verify no residual conflict markers, no fabricated citations (diff AI output citations against the union of input citations), LaTeX/Markdown syntax validity, and word count within ±20% of combined input length.
5. **Store**: Write results to Supabase `ai_suggestions` table with per-conflict confidence scores. Notify connected clients via Supabase Realtime.

### Prompt engineering for academic merge resolution

The system prompt establishes five inviolable principles: **preservation** (never alter citations, DOIs, or attributions), **fidelity** (use only text from base/ours/theirs — never generate new scholarly claims), **combination** (merge complementary changes with appropriate transitions), **transparency** (explain reasoning and flag uncertainty), and **academic tone** (maintain formal register and disciplinary conventions). Resolution strategies are ranked: combine > prefer-with-context > minimal rewrite > flag for human review.

Research from merde.ai (a production merge resolution tool) found that **simply feeding conflict markers to an LLM "scored single digits"** on benchmarks. Performance jumped to ~50% when the LLM was given broader context: commit messages, surrounding document structure, and related file changes. For academic documents, this means including section headings, the document's abstract, and the bibliography alongside each conflict region.

**Prompt caching** is essential for cost control. The system prompt, style guide, and base document are placed first and cached (90% cost reduction on cache reads). Per-conflict variable content comes after. A typical academic paper merge (~20K tokens base + 5K conflicts + 2K system prompt) costs approximately **$0.08–$0.40 per run** depending on model choice. For non-urgent processing, the Batch API offers an additional 50% discount.

Use Claude's **structured outputs** to guarantee the response matches a typed schema: each `ConflictResolution` includes `resolved_text`, `strategy` (combine/prefer_ours/prefer_theirs/rewrite/needs_human_review), `reasoning`, `confidence` (0.0–1.0), `citations_affected` flag, and optional `warnings`. Any resolution with confidence below **0.7** is automatically flagged as requiring human review.

---

## Real-time collaboration without abandoning Git

The central tension — Git's asynchronous commit model versus users expecting real-time editing visibility — resolves through a **hybrid CRDT + Git architecture**. During active sessions, **Yjs** (900K+ weekly npm downloads, MIT licensed) provides sub-100ms collaborative editing via its `Y.Text` shared type, synced through a **y-websocket** server. Yjs integrates directly with ProseMirror/TipTap via official bindings, including the Awareness protocol for cursor presence.

The Git Sync Service periodically (every 30–60 seconds during active editing, or on explicit "save") serializes the Yjs document state to Markdown, commits locally, and pushes to GitHub. When no active session exists, the Git state is canonical — incoming changes from merged PRs or external edits are pulled, converted to Yjs initial state, and propagated to reconnecting clients.

**Conflict between CRDT and Git states** is handled by treating CRDT as authoritative during active sessions and Git as authoritative between sessions. Before committing Yjs→Git, the sync service checks whether Git HEAD has advanced (external changes). If so, it pulls changes, attempts automatic merge, and alerts users if conflicts arise. This mirrors how Overleaf works internally (OT + periodic persistence), but uses the more modern and distributed CRDT approach.

For the web app without Tauri's local Git, the server acts as the Git intermediary: all Git operations flow through the API server, which uses Octokit.js to interact with GitHub. For the Tauri desktop app, git2-rs operates on a local clone, providing offline capability with sync-on-reconnect.

---

## Document diff visualization for academic prose

**Word-level diffing** is the right granularity for academic prose — character-level diffs produce confusing partial-word highlights, while sentence-level misses subtle edits. The **jsdiff library** (`diffWords` method, 15M+ weekly npm downloads) provides the core algorithm, with `diffSentences` available for high-level structural overviews.

For the editor itself, **TipTap** (built on ProseMirror) with the prosemirror-changeset module provides live track-changes capability. Each change carries metadata (user, timestamp) and can be individually accepted or rejected. TipTap's Snapshot Compare extension (commercial) diffs between saved versions with user-filtered change views.

**Unified inline diff view** — insertions in green, deletions in red strikethrough — is strongly preferred over side-by-side for prose, matching the track-changes convention researchers expect from Word. For Git-level diffs (comparing branches or commits), the pipeline is: extract both text versions from Git → compute word-level diff via jsdiff → render as HTML with `<ins>`/`<del>` markup.

A critical detail: treat **`@citekey` references as atomic tokens** during diffing. Never character-diff inside a citation key. Separately diff the `references.json` bibliography file to surface added/removed/modified citations as distinct reviewable events.

---

## Key risks and technical gotchas

**GitHub API rate limits are the primary scaling constraint.** At 5,000 requests/hour for standard GitHub Apps (scaling to 12,500 with many repos), a platform with hundreds of active projects must implement aggressive caching, conditional requests (304 responses don't count against limits), and GraphQL batching. The `createCommitOnBranch` mutation replacing 4–6 REST calls is essential.

**The `mergeable` field on PR responses can be `null`** if GitHub hasn't computed mergeability yet. The first GET triggers background computation; the app must poll with backoff until the value resolves. This is a common source of race conditions.

**git2-rs authentication is notoriously complex.** The callback-based credential system requires wrapper crates (`auth-git2` or `git2_credentials`). For Tauri desktop, test authentication flows across all three platforms (macOS/Windows/Linux) with both SSH keys and HTTPS tokens early in development.

**Tauri's cross-platform WebView inconsistency** is a real concern. WKWebView (macOS), WebView2 (Windows), and WebKitGTK (Linux) render CSS and handle APIs differently. Test extensively on all platforms — especially WebKitGTK on Linux, which lags behind in web standards support.

**AI citation hallucination** is the highest-risk failure mode for academic credibility. While merge resolution (combining existing text) carries lower hallucination risk than generation tasks, the post-processing validation pipeline — extracting citations from AI output and diffing against the input citation registry — is non-negotiable. Research shows AI tools hallucinate **17–55% of citations** when generating academic content from scratch; constraining the AI to work only with existing material drastically reduces but doesn't eliminate this risk.

**CRDT↔Git reconciliation** adds significant complexity. Edge cases include: concurrent edits in Yjs while an external PR merges on GitHub; network partitions during sync; and the Yjs binary state diverging from the plain-text Git representation after certain editing patterns. Build a comprehensive test suite for these scenarios before launch.

**Supabase RLS performance degrades with complex policies.** Simple ownership checks add minimal overhead, but policies involving joins to the `project_members` table can cause **2–11x query slowdowns**. Use `SECURITY DEFINER` helper functions and ensure all RLS-referenced columns are properly indexed.

**GitHub's free tier LFS limits** (1 GB storage, 1 GB/month bandwidth) will constrain projects with many figures. Plan for paid LFS data packs or consider hosting binary assets outside Git (Supabase Storage or S3) with Git tracking only for text source files.

---

## Conclusion: what makes this architecture work

Three architectural decisions define the platform's viability. First, **Pandoc-flavored Markdown as the canonical format** with CSL JSON bibliographies provides the cleanest Git diffs while enabling output to any academic format — this is the bridge between Git-native workflows and researcher accessibility. Second, the **dual-layer permission model** (GitHub branch protection + Supabase RLS) solves the granularity gap that no existing tool addresses, enforcing scholarly roles without requiring researchers to understand Git permissions. Third, the **architectural separation between AI read-only analysis and human-authorized writes** — enforced at the infrastructure level, not just the UI level — ensures the human-in-the-loop requirement cannot be circumvented by bugs or edge cases.

The platform's true competitive moat is the combination of these elements. Any single feature (AI merging, Git-backed versioning, citation tracking, real-time editing) could be replicated. But the integrated system — where a contributor's suggested edit triggers a PR, reviewer comments automatically feed into AI merge proposals, the maintainer reviews AI suggestions with per-conflict granularity, and every action is attributed and auditable through Git history — creates a workflow that doesn't exist anywhere in academic publishing today.