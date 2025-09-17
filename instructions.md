## Quick Reference for Agents
Use these CLI tools to locate sources, read full text, and fetch citations. Tools are on your PATH; call them directly (no `./` required). Inputs can be LaTeX-style citations (e.g., `\citet{key}`) or bare BibTeX keys (e.g., `author:year_title`).

### Core Tools
- cite2md — print a Markdown fulltext path or content for a citation/key
  - Accepts multiple keys via args or stdin; use `--cat` to stream content.
- cite2bib — print the corresponding BibTeX entry for a citation/key
- path2key — infer the BibTeX key from a filename or path
- find-bib — search the bibliography by fields; output keys or BibTeX
- rg-sources — ripgrep search across Markdown fulltext of available sources (use `--cat` to stream content)
- fd-sources — filename search across Markdown sources (use `--cat` to stream content)
- cat-sources — print contents of source files from a filename

### Common Tasks
- Read full text for a citation
  - `cite2md --cat "\citet{vesper:2012_jumping}"`
  - `printf '%s\n' vesper:2012_jumping butterfill:2019_goals | cite2md --cat`
- Get the file path for a key
  - `cite2md vesper:2012_jumping`
- Fetch a BibTeX entry
  - `cite2bib vesper:2012_jumping`
  - `cite2bib "\citet{vesper:2012_jumping}"`
- Recover a BibTeX key from a filename
  - `path2key "Vesper et al. - 2012 - Are You Ready to Jump Predictive Mechanisms vesper2012_jumping.md"`
- Find relevant entries by fields
  - Keys: `find-bib --author steward --year 2009 --title animal`
  - BibTeX: `find-bib --author smith --cat`
  - (keys only by default; add --cat for BibTeX)
- Search within all fulltext sources
  - `rg-sources -n "bayesian prior"`
  - `rg-sources -i -C2 "causal effect"`
  - Stream matching files: `rg-sources -i "causal effect" --cat`
- Locate files by filename
  - `fd-sources vesper2012_jumping`
  - `fd-sources -i 'butterfill.*2019'`
  - Stream matched files: `fd-sources vesper2012_jumping --cat`

- Read files found by other tools
  - From `fd-sources`: `fd-sources vesper2012_jumping | cat-sources`
  - From `rg-sources`: `rg-sources -l 'bayesian prior' | cat-sources`
  - From a citation/key: `cite2md vesper:2012_jumping | cat-sources`

### Missing fulltext
- When `cite2md` cannot resolve a key, it prints a standardized message to stderr and appends the key to `missing-fulltext.txt` in the current working directory (one key per line) for follow‑up.

### Missing BibTeX entries
- When `cite2bib` cannot resolve a key in the BibTeX file, it prints a standardized message to stderr and appends the key to `missing-keys.txt` in the current working directory (one key per line).

### Notes
- Prefer `cite2md`/`cite2bib` to move between citations/keys and fulltext/BibTeX quickly when reviewing drafts.
- Use `find-bib` to discover related literature by author, year, title terms, or abstract snippets.
- `path2key` helps when you only have a filename and need the citation key.
- For options and flags, run `--help` on any command.
