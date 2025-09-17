# fd-sources — Search source filenames in PAPERS_DIR

Goal
- Quickly locate source files by filename (typically includes author, year, title), even if not listed in the BibTeX file.

Command
- `fd-sources [fd-flags...] [--] [pattern] [paths...]`
- `fd-sources [fd-flags...] --cat [pattern]`

Behavior
- Mirrors `rg-sources` scoping: runs searches inside `PAPERS_DIR` and blocks absolute or parent-directory paths.
- Always restricts to Markdown sources: adds `--extension md --extension mdx` and does not allow overrides via `-e/--extension`.
- Passes other flags and patterns through to `fd` unchanged.
- `--cat` streams matched files through `cat-sources` (equivalent to piping results).

Exit codes
- 0: success (printed at least one match)
- 1: no matches
- 2: usage/config error (e.g., missing `fd` or missing `PAPERS_DIR`)

Examples
- `fd-sources vesper2012_jumping` — print path(s) with that normalized key suffix
- `fd-sources -i 'vesper.*jump'` — case-insensitive fuzzy match on filename
- `fd-sources vesper2012_jumping --cat` — stream file contents for matches
