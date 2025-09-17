# index-sources — Build/update bibtex-index.jsonl (Proposed)

Purpose
- Construct a simple JSONL index mapping files in `PAPERS_DIR` to BibTeX keys, validating keys as desired.

CLI
- `index-sources [--write] [--validate] [--extensions md,mdx]`
- Help: `-h|--help`

Behavior
- Scans `PAPERS_DIR` for files with given extensions (default: `md,mdx`).
- For each file, determine `key` via `path2key`.
- Emit JSONL: `{ "key": K, "filename": B, "path": REL }` where `REL` is path relative to `PAPERS_DIR`.
- `--validate`: only emit entries whose `key` resolves via `cite2bib`; otherwise include with an `invalid: true` flag.
- `--write`: write to `$PAPERS_DIR/bibtex-index.jsonl` atomically (temp file + move), else print to stdout.

Exit Codes
- 0: success (wrote or printed at least one entry)
- 1: no files found
- 2: usage/config error (e.g., missing `PAPERS_DIR`)

Dependencies
- `fd`, `path2key`, optionally `cite2bib` for `--validate`.

Examples
- `index-sources --validate > index.jsonl`
- `index-sources --write`

