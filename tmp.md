# Proposal: Accessing Authored .tex Sources and General Citation Resolution

## Goals
- Make it easy for agents to get full text for authored works referenced via a BibTeX key.
- Keep the mental model consistent: list → choose → read one.
- Avoid surprising behavior when a format is rarely available.

## Constraints & Current State
- ~6k Markdown sources in `PAPERS_DIR`; ~20 LaTeX `.tex` sources (growing) in `PAPERS_DIR/data/tex-sources/` (or configured location).
- `.tex` files are named by the BibTeX key with `:` removed, e.g., `butterfill2025_three.tex` for `butterfill:2025_three`.
- Books span multiple parts: `butterfill2020_developing_1.tex`, `butterfill2020_developing_2.tex`, … for `butterfill:2020_developing`.
- Current agent workflow: `draft2keys` → list keys → `cite2md` for path/content → `cat-sources` to read.
- We have standardized missing handling and nudged toward “list → read one”.

## Options

### Option A — Add a dedicated “key → .tex” tool (minimal, explicit)
- New tool: `cite2tex`
  - Input: citation/key(s) via args or stdin (same semantics as `cite2md`).
  - Output: one `.tex` path per key; for books, output all parts in numeric order (…_1.tex, …_2.tex, …).
  - No `--cat`; agents use `cat-sources` (keeps stdout pure, matches “list → read one”).
  - Missing handling:
    - Stderr: `MISSING cite2tex: <key> (normalized: <normkey>) in <PAPERS_DIR>`
    - Log: append `<key>` to `./missing-tex.txt` (one per line)
- Pros: clear, discoverable, low-risk; leverages existing naming pattern; macOS-friendly (rg/awk/sed).
- Cons: adds one focused tool.

### Option B — List available representations for a key (general, future‑proof)
- New tool: `key2files` (aka `sources-of`)
  - Input: key(s)
  - Output (one per line): `type<TAB>path` (e.g., `md\t...`, `tex\t...`, `tex_part_2\t...`).
  - Agents select a path and use `cat-sources` to read.
- Pros: unifies access to multiple formats (MD/TEX/PDF later) without new flags; great UX for “what’s available”.
- Cons: another tool; agents still choose which path to read (by design).

### Option C — Integrate `.tex` fallback into `cite2md` (hidden, opt‑in)
- Behavior: `cite2md` tries Markdown first; if not found, tries `.tex` when `CITE2MD_TEX_FALLBACK=1` is set.
- Pros: no new tool.
- Cons: hidden behavior; risks confusion when receiving LaTeX rather than Markdown; harder to reason about outputs; not recommended now.

### Option D — Convert ordinary citations in any Markdown to BibTeX keys (harder, broader)
- New tool: `md2keys` (future exploration)
  - Parse ordinary citations (e.g., “Surname, YYYY”; “Surname (YYYY)”; DOI/URL), generate candidates via `find-bib` (`--author`, `--year`, optional title tokens), rank/filter, and emit keys.
- Pros: broad utility beyond authored `.tex` sources.
- Cons: non‑trivial heuristics, ambiguity handling, ranking; larger design effort.

## Recommendation (Phased)
1) Implement Option A (`cite2tex`) now
   - Keep it explicit and minimal; no impact on `cite2md`.
   - Example (fallback from Markdown to `.tex`):
     - `key=$(sed -n '1p' keys.txt)`
     - `p=$(cite2md "$key" 2>/dev/null || true)`
     - `if [ -z "$p" ]; then p=$(cite2tex "$key"); fi`
     - `cat-sources "$p"`
   - For books: `p=$(cite2tex butterfill:2020_developing | sed -n '1p'); cat-sources "$p"`

2) Plan for Option B (`key2files`) next
   - A single “what’s available for this key” lister makes format choice explicit and scales to future additions (PDF/HTML).
   - Example: `key2files butterfill:2020_developing > files.txt; sed -n '1p' files.txt | cut -f2 | xargs -I{} cat-sources "{}"`

3) Defer Option C (hidden fallback)
   - Avoids surprising agents with LaTeX when they expected Markdown; keeps `cite2md` responsibilities tight.

4) Explore Option D (`md2keys`) in a separate track
   - Start with conservative patterns: “Surname, YYYY” and “Surname (YYYY)” → filter via `find-bib`.
   - Emit candidates with scores; require human/agent pick when ambiguous.

## UX Notes
- Keep the “list → then read one” pattern in examples across tools.
- Reserve “stream many” to rare exceptions; attribution back to a key/file is otherwise harder.
- Standardize missing behavior for `.tex` (as with Markdown/BibTeX): stderr + local log file.

## Implementation Notes (macOS‑friendly)
- Use `rg` (ripgrep) for fast listing, `awk`/`sed` for splitting/ordering (avoid GNU‑only flags).
- Part ordering for books: numeric suffix sort (`*_1.tex`, `*_2.tex`, …).
- `.tex` root discovery: default to `$PAPERS_DIR/data/tex-sources` (or `$PAPERS_DIR` if flat), configurable via env if needed.

## Effort & Risk
- Option A: Low; small script, consistent logging, simple tests.
- Option B: Low/Medium; glue tool around existing resolution; clean spec.
- Option D: Medium/High; requires iteration and careful evaluation.

## Next Steps
- Draft `cite2tex` spec and help text (paths‑only, no `--cat`), include missing logging (`missing-tex.txt`).
- Add concise instructions.md snippets: fallback from `cite2md` to `cite2tex` when path is empty.
- (Later) Draft `key2files` spec for unified listing.
