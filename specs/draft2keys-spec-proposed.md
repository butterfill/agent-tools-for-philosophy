# draft2keys — Extract cited keys from drafts (Proposed)

Purpose
- Parse a draft (LaTeX/Pandoc Markdown) and emit unique BibTeX keys; optionally chain into fulltext or BibTeX.

CLI
- `draft2keys <draft-file> [--keys|--paths|--cat|--bib]`
- Output modes (default `--keys`):
  - `--keys`: print keys, one per line (default)
  - `--paths`: print absolute Markdown fulltext paths via `cite2md`
  - `--cat`: stream fulltext for all cited keys (`cite2md | cat-sources`)
  - `--bib`: print BibTeX entries via `cite2bib`
- Help: `-h|--help`

Behavior
- Recognizes citations:
  - LaTeX: `\cite...{key}` (support multiple comma-separated keys)
  - Pandoc Markdown: `[@key]` and `@key`
- Normalizes and deduplicates keys; preserves original colon/casing where possible.
- Orders output by first occurrence in the document.

Exit Codes
- 0: printed at least one item in the chosen mode
- 1: no citations found
- 2: usage/config error (e.g., unreadable draft)

Dependencies
- `rg` (or portable `sed`/`awk`), `cite2md`, `cat-sources`, `cite2bib`.

Examples
- Keys only: `draft2keys draft.md`
- Read all: `draft2keys draft.md --cat`
- BibTeX packet: `draft2keys draft.md --bib`

