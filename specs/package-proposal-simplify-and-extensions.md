# Agent Tools Package: Simplify and Extend (Proposal)

Audience
- AI coding/analysis agents (codex, Claude Code, rovodev, etc.) focused on philosophical analysis: reading, searching, quoting, and citing.

Goals
- Keep mental model simple: discover → read → quote/cite.
- Reduce friction for common review tasks from README scenarios.
- Maintain safety and scoping to `PAPERS_DIR` and existing bibliographic sources.

Keep (as-is)
- `rg-sources`, `fd-sources`, `cat-sources` — the discover → read trio.
- `cite2md`, `cite2bib` — clean separation: path/fulltext vs. BibTeX.
- `path2key` — reverse lookup to connect paths/snippets back to citations.

Small Unifications (non-breaking, optional)
- Aliases as affordances, not replacements:
  - `key2path` → thin wrapper for `cite2md` (path mode only).
  - `keys2cat` → batch read by keys (stdin) using `cite2md | cat-sources`.

New Tools (proposed)
- `snip-sources` — find and emit quotable snippets with context and traceability.
- `draft2keys` — extract unique BibTeX keys from a draft (LaTeX/Pandoc).
- `keys2cat` — batch read sources by keys or citations (stdin-first design).
- `index-sources` — build/update `$PAPERS_DIR/bibtex-index.jsonl` from the filesystem.
- `validate-sources` — report on file/index/key consistency issues.

Why these help philosophers
- Snippets with context and a back-link to the key accelerate argument analysis while preserving traceability.
- Draft → keys → fulltext/BibTeX pipelines make fact‑checking one-liners.
- Lightweight maintenance keeps the environment reliable without manual effort.

Common Flows (with proposed tools)
- Quote hunt with traceability: `snip-sources -i --json "causal effect"`
- Read all sources cited in a draft: `draft2keys draft.md --cat`
- Curate a topic pack: `find-bib --abstract "joint action" --limit 10 | keys2cat`
- File hygiene: `index-sources --write && validate-sources`

Compatibility & Scope
- No breaking changes to existing tools.
- Proposed tools mirror conventions: `#!/usr/bin/env bash`, `set -euo pipefail`, clear `--help`, exit codes (0/1/2), scoped to env vars (`PAPERS_DIR`, `BIB_FILE`), and minimal dependencies (`fd`, `rg`, `jq`).

