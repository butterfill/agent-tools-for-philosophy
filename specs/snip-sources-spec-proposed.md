# snip-sources — Search and emit traceable snippets (Proposed)

Purpose
- Find matches in Markdown sources and emit quotable snippets with minimal context and a back-link to the citation key.

CLI
- `snip-sources [rg-flags...] [--] pattern`
- Output control:
  - `--json` (default): JSONL objects with `{ path, key, line, match, before, after }`.
  - `--md`: emit Markdown blockquotes with a citation label (footnote-style).
  - `--context N` (default: 1): lines before/after to include.
- Help: `-h|--help`

Behavior
- Scope to `PAPERS_DIR` and default Markdown types (like `rg-sources`).
- Uses `rg --json` for robust match coordinates; groups per file.
- Resolves `key` via `path2key` for each `path`.
- Deduplicates identical matches within the same file.

Output
- `--json` (default): one JSON object per match with fields:
  - `path` (relative to `PAPERS_DIR`), `key`, `line` (1-based), `match` (text), `before` (array), `after` (array)
- `--md`: a blockquote including minimal context and a trailing cite like `[^key:line]`.

Exit Codes
- 0: at least one snippet printed
- 1: no matches
- 2: usage/config error (e.g., missing `rg`/`path2key`, `PAPERS_DIR` not found)

Dependencies
- `rg`, `path2key` (for keys), standard utilities (`jq` optional for formatting only).

Examples
- `snip-sources -i --json "causal effect"`
- `snip-sources --context 2 --md "joint action"`

