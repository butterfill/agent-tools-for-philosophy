# validate-sources — Check source/index/key consistency (Proposed)

Purpose
- Report on issues linking files, index, and BibTeX keys; keep the environment healthy.

CLI
- `validate-sources [--index $PAPERS_DIR/bibtex-index.jsonl] [--extensions md,mdx]`
- Help: `-h|--help`

Checks
- Files under `PAPERS_DIR` whose inferred key (`path2key`) does not validate via `cite2bib`.
- Duplicate keys mapping to multiple files.
- Index entries pointing to missing files; files not present in the index.
- Optional: mismatches between index `.filename` and the actual basename.

Output
- Human-readable report to stdout; diagnostics to stderr.
- Exit non-zero if any issues are found; exit 0 when clean.

Exit Codes
- 0: clean (no issues)
- 1: issues found
- 2: usage/config error

Dependencies
- `fd`, `path2key`, `cite2bib`, `jq` (if index is used for cross-checks).

Examples
- `validate-sources`
- `validate-sources --index "$PAPERS_DIR/bibtex-index.jsonl"`

