# Lab Repo Prompt

Copy/paste this prompt into any AI session working on a repo you want to surface as a Lab on michaelwong.life.

---

You are preparing this repository to be auto-published as a "Lab" on michaelwong.life. The site fetches content via the GitHub API at build time — there is no manual upload step. Conform to **all** of the following or the entry will render broken.

## 1. Cover image — REQUIRED

- Save **exactly one** hero screenshot at `docs/screenshot.png` on the `main` branch.
- Format: PNG, **16:9** aspect ratio, **min 1600×900**, **max 2 MB**.
- Subject: a real product/UI shot (no Figma mockups, no placeholder gradients, no AI-generated stock art). If the project is a CLI, screenshot the terminal with a real run.
- The site loads it raw from `https://raw.githubusercontent.com/{owner}/{repo}/main/docs/screenshot.png` — verify the URL returns 200 before claiming you're done.

## 2. Repo metadata — REQUIRED

- Set the GitHub **About → Description** to one sentence, ≤ 140 chars, present tense, no trailing period. This becomes the lab card subtitle.
- Set GitHub **Topics**: 3–6 lowercase, hyphenated tags (e.g. `swiftui`, `git`, `academic-collaboration`). The first 6 are rendered as chips on the lab page.
- The repo must be **public**, default branch **`main`**.

## 3. README.md — narrative body

- The README is rendered verbatim as the lab page narrative — write it for a portfolio reader, not a contributor.
- **Order:**
  1. One-paragraph hook (what it is + why it matters). No "Welcome to…".
  2. `## Screenshots` — reference `./docs/screenshot.png` and any extra images via relative paths under `docs/`. Use plain markdown `![alt](./docs/foo.png)`.
  3. `## How it works` — 2–4 short paragraphs, plain prose.
  4. `## Stack` — bulleted list, one line per technology.
  5. `## Status` — one line: `Active`, `Archived`, or `In progress`.
- **Do not include:** build badges, install instructions, contribution guides, license boilerplate, table of contents, or `<details>` collapsibles. Move all of those to a separate `CONTRIBUTING.md` or the bottom of the file.
- Headings start at `##` (the site supplies the H1 from the repo name).
- Keep total length under ~400 words.

## 4. Image conventions for in-README screenshots

- Place every image under `docs/` (never `assets/`, never repo root).
- Use **kebab-case** filenames: `docs/dashboard-empty-state.png`.
- Same format rules as the cover: PNG, 16:9 preferred, ≤ 2 MB each.
- Always provide meaningful alt text.
- No animated GIFs over 5 MB. Prefer a still + a link to a video.

## 5. Title hygiene

The lab title on the site is auto-derived from the **repo name** with hyphens replaced by spaces. So name the repo the way you want it to appear: `OpenTwig` → "OpenTwig", `constellation-a2a` → "constellation a2a". Rename the repo before merging if the casing is wrong.

## 6. Verify before claiming done

Run these checks and report the results:

1. `curl -sI https://raw.githubusercontent.com/{owner}/{repo}/main/docs/screenshot.png` → must return `HTTP/2 200`.
2. `gh repo view {owner}/{repo} --json description,topics,visibility,defaultBranchRef` → description non-empty, topics ≥ 3, visibility `PUBLIC`, default branch `main`.
3. README renders correctly on github.com/{owner}/{repo} with the cover image visible.

Only after all three pass: commit + push to `main`.

---

## After the AI is done — register the lab on the site

Add the repo to `lib/github-labs.ts` in the michaelwong.life codebase so the build picks it up. The site does the rest.
