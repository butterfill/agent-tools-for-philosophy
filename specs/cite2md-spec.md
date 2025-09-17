# cite2md — Resolve a citation/key to a Markdown fulltext path

Resolves a LaTeX-style citation or BibTeX key to the corresponding Markdown file in the local papers directory. Optionally prints the file contents or just the first sentence.

## Name & Purpose
- Command: `cite2md`
- Goal: Given `\citet{key}`, a `key` with colons, or a normalized `key` without colons, print the absolute Markdown file path, the file contents, or the first sentence.

## Configuration & Env Vars
- `PAPERS_DIR` (default: `$HOME/papers`)
  - Root of local fulltext sources.
- Index path (internal): `$PAPERS_DIR/bibtex-index.jsonl`
  - Newline‑delimited JSON objects with fields like `.key`, `.path`, `.filename`.

## Inputs
- Flags:
  - `--cat` — print file contents instead of path
  - `-h|--help` — help text
- Positional: `citation-or-key`
  - LaTeX style: e.g., `"\citet{vesper:2012_jumping}"` (extracts inner `{…}`)
  - Key with colons: e.g., `vesper:2012_jumping`
  - Normalized key: e.g., `vesper2012_jumping`

## Resolution Strategy
1) Parse key and derive `normkey` (remove `:` from key).
2) Direct filename lookup using `fd` under `$PAPERS_DIR`:
   - Regex: `${normkey}\.md$`; take the first match.
3) Fallback to index (`$PAPERS_DIR/bibtex-index.jsonl`) if present:
   - First try `select(.key == key) | .path // .filename`.
   - If not found, try normalized match: `select((.key|gsub(":";"")) == normkey) | .path // .filename`.
   - Resolve to `$PAPERS_DIR/<rel>` and ensure the file exists.
4) If no file is found, exit non‑zero with a concise error including both forms of the key.

## Output Modes
- Default (no flag): print absolute file path only.
- `--cat`: print the entire file to stdout.

## Exit Codes
- 0: success
- 1: not found
- 2: usage error (e.g., missing input)

## Dependencies
- Required: `fd`, `jq`, `sed`, `awk`

## Examples
- Path from LaTeX citation:
  - `cite2md "\citet{vesper:2012_jumping}"`
- Print file contents:
  - `cite2md -c vesper:2012_jumping | sed -n '1,10p'`
- Print the first sentence:
  - `cite2md -1 vesper2012_jumping`
