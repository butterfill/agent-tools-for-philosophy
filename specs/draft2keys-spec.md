# draft2keys — Extract cited keys from drafts

Extracts BibTeX citation keys from a draft and either prints the unique keys or streams the corresponding full text. Keeps a single, simple flag (`--cat`) to match the suite’s pattern.

## Name & Purpose
- Command: `draft2keys`
- Goal: Given a draft file, parse supported citation syntaxes, normalize and de‑duplicate keys in first‑occurrence order, and either:
  - print keys (default), or
  - stream full text for each cited key with `--cat`.

## CLI
- `draft2keys [--cat] <draft-file>`
- Help: `-h|--help`

## Citation Formats
- LaTeX: `\cite...{key}` with support for comma‑separated keys inside braces.
- Pandoc Markdown: `@key` and `[@key]` forms.

## Behavior
- Reads the draft file, extracts keys from the supported forms, de‑duplicates them and preserves their first appearance order.
- Keys are emitted exactly as parsed (including colons/casing as in the draft).
- Default mode prints keys, one per line.
- `--cat` mode resolves each key to a Markdown fulltext file via `cite2md` and streams concatenated content.
- Continues processing even if some keys cannot be resolved; success is determined by whether any output was produced in the chosen mode.

## Missing Handling (stderr + logs)
- Full text not available (when `--cat`): conforms to `cite2md` behavior.
  - Stderr: `MISSING cite2md: <key> (normalized: <normkey>) in <PAPERS_DIR>`
  - Log: appends `<key>` to `./missing-fulltext.txt` (one per line)
- BibTeX key not found (only applicable if future modes query BibTeX): must conform to `cite2bib` behavior.
  - Stderr: `MISSING cite2bib: <key> (normalized: <normkey>) in <BIB_FILE>`
  - Log: appends `<key>` to `./missing-keys.txt` (one per line)
- Malformed citations (cannot parse a key): emit a concise diagnostic to stderr and skip.

## Exit Codes
- 0: at least one item printed (keys in default mode, or content in `--cat`)
- 1: no citations found, or none could be resolved in `--cat`
- 2: usage/config error (e.g., missing/unreadable draft)

## Dependencies
- Extraction: `rg`/`sed`/`awk` (portable line scanning and capture).
- `--cat` mode: `cite2md` (which in turn uses `cat-sources`).

## Examples
- Keys only:
  - `draft2keys notes/draft.md`
- Read all cited sources:
  - `draft2keys notes/draft.md --cat`

