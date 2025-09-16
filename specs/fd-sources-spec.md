# fd-sources — Search source filenames in PAPERS_DIR

Goal
- Quickly locate source files by filename (typically includes author, year, title), even if not listed in the BibTeX file.

Command
- `fd-sources [fd-flags...] [--] [pattern] [paths...]`

Behavior
- Mirrors `rg-sources` scoping: runs searches inside `PAPERS_DIR` and blocks absolute or parent-directory paths.
- Defaults to Markdown sources: adds `--extension md --extension mdx` unless caller supplies their own `--extension/-e`.
- Passes all other flags and patterns through to `fd` unchanged.

Exit codes
- 0: success (printed at least one match)
- 1: no matches
- 2: usage/config error (e.g., missing `fd` or missing `PAPERS_DIR`)

Examples
- `fd-sources vesper2012_jumping` — print path(s) with that normalized key suffix
- `fd-sources -i 'vesper.*jump'` — case-insensitive fuzzy match on filename
- `fd-sources -e md -e mdx 'butterfill:2019'` — explicit extensions (overrides defaults)

