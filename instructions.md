## Tools for Searching, Reading and Citing Sources
Use these CLI tools to locate sources, read full text, and fetch citations. Tools are on your PATH; call them directly (no `./` required). Inputs can be LaTeX-style citations (e.g., `\citet{key}`) or bare BibTeX keys (e.g., `author:year_title`).

### The Tools
- cite2md — print a Markdown fulltext path or content for a citation/key
  - Use `--cat` to stream content for a single key.
- draft2keys — extract keys from a draft (prints unique keys)
- cite2bib — print the corresponding BibTeX entry for a citation/key
- path2key — infer the BibTeX key from a filename or path
- find-bib — search the bibliography by fields; output keys or BibTeX
- rg-sources — ripgrep search across Markdown fulltext of available sources
- fd-sources — filename search across Markdown fulltext sources
- cat-sources — print contents of source files from a filename

### Common Tasks (list → then read one)
- Fact-check a draft (keys → read one-by-one)
  - List keys: `draft2keys draft.md > keys.txt`
  - Inspect first key’s full text:
    - `key=$(sed -n '1p' keys.txt)`
    - `cite2md --cat "$key"`
  - Repeat per key; take notes as you go. Compile a report at the end.
- Read full text for a citation/key
  - `cite2md --cat "\citet{vesper:2012_jumping}"`
- Get the file path for a key
  - `cite2md vesper:2012_jumping`
- Fetch a BibTeX entry
  - `find-bib --author smith | sed -n '1p'`
  - `cite2bib vesper:2012_jumping`
- Recover a BibTeX key from a filename
  - `path2key "Vesper et al. - 2012 - Are You Ready to Jump ... vesper2012_jumping.md"`
- Search within all fulltext sources (list paths first)
  - `rg-sources -n "bayesian prior"`
  - `rg-sources -i -C2 "causal effect"`
  - `rg-sources -l -i "causal effect" > hits.txt`
  - `p=$(sed -n '1p' hits.txt); cat-sources "$p"`
- Locate files by filename (list, then choose one)
  - `fd-sources vesper2012_jumping > files.txt`
  - `p=$(sed -n '1p' files.txt); cat-sources "$p"`

- Read files found by other tools
  - From `fd-sources`: `fd-sources vesper2012_jumping | cat-sources`
  - From `rg-sources`: `rg-sources -l 'bayesian prior' | cat-sources`
  - From a citation/key: `cite2md vesper:2012_jumping | cat-sources`
  - From a draft: `draft2keys draft.md | cite2md --cat`

### Missing fulltext
- When `cite2md` cannot resolve a key, it prints a standardized message to stderr and appends the key to `missing-fulltext.txt` in the current working directory (one key per line) for follow‑up.

### Missing BibTeX entries
- When `cite2bib` cannot resolve a key in the BibTeX file, it prints a standardized message to stderr and appends the key to `missing-keys.txt` in the current working directory (one key per line).

### Notes
- Prefer `cite2md`/`cite2bib` to move between citations/keys and fulltext/BibTeX quickly when reviewing drafts.
- Use `find-bib` to discover related literature by author, year, title terms, or abstract snippets.
- `path2key` helps when you only have a filename and need the citation key.
- For options and flags, run `--help` on any command.
