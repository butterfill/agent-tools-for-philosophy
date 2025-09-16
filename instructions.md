## Finding the fulltext of a cited source
You should be able to execute the following shell commands:
  - cite2md.sh - resolve citation/key to Markdown fulltext path
  - cite2bib.sh - resolve citation/key to BibTeX entry
  - path2key.sh - resolve a file path (absolute, relative or basename) to a BibTeX key (validates against cite2bib.sh)

The tools are on your PATH, so no `./` prefix is needed.

**Usage examples:**
- `cite2md.sh -c "\citet{vesper:2012_jumping}"` — get full text from LaTeX citation
- `cite2md.sh "vesper:2012_jumping"` — get full text from BibTeX key
- `cite2bib.sh "\citet{vesper:2012_jumping}"` — get BibTeX entry from LaTeX citation  
- `cite2bib.sh "vesper:2012_jumping"` — get BibTeX entry from BibTeX key
- `path2key.sh "some notes vesper2012_jumping.md"` — get BibTeX key from filename (uses filename-first heuristic and validates with cite2bib.sh)
- `path2key.sh "random-nonheuristic-name.md"` — check index fallback via `$PAPERS_DIR/bibtex-index.jsonl` if present

**Note:** The tools accept either LaTeX-style citations (with `\citet{}`) or bare BibTeX keys. 

Please check you can execute the shell commands `cite2md.sh` and `cite2bib.sh` to obtain info for the key `vesper:2012_jumping`.  Use their `--help` as needed.  **If you cannot execute these commands, stop immediately and report the error.**

## Searching sources in PAPERS_DIR
You can search across the Markdown sources in the papers directory with:
  - rg-sources — ripgrep scoped to `$PAPERS_DIR` (default: `$HOME/papers`)

Behavior:
- Runs inside `$PAPERS_DIR` and searches only there.
- Defaults to Markdown types: `*.md`, `*.markdown`, `*.mdx`.
- Pass any ripgrep flags as usual; your own `-t/-T/--glob/--iglob/--type-*` overrides defaults.
- Absolute or parent-directory paths are not allowed (hard error). Use paths relative to `$PAPERS_DIR`.

Usage examples:
- `rg-sources -n "bayesian prior"` — search all markdown with line numbers.
- `rg-sources -i -C2 "causal effect"` — case-insensitive with 2 lines context.
- `rg-sources "kernel trick" notes/ ml/` — restrict to subfolders under `$PAPERS_DIR`.
- `rg-sources -t mdx -S "export const"` — search only MDX, smart-case.
- `rg-sources -g "drafts/**" "gradient"` — use your own glob; disables default type filter.
