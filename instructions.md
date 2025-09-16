## Finding the fulltext of a cited source
You should be able to execute the following shell commands:
  - cite2md - resolve citation/key to Markdown fulltext path
  - cite2bib - resolve citation/key to BibTeX entry
  - path2key - resolve a file path (absolute, relative or basename) to a BibTeX key
  - find-bib - search bibliography by fields and emit BibTeX keys/entries
  - rg-sources — search fulltext of souces with ripgrep syntax

The tools are on your PATH, so no `./` prefix is needed.

**Usage examples:**
- `cite2md -c "\citet{vesper:2012_jumping}"` — get full text from LaTeX citation
- `cite2md "vesper:2012_jumping"` — get full text from BibTeX key
- `cite2bib "\citet{vesper:2012_jumping}"` — get BibTeX entry from LaTeX citation  
- `cite2bib "vesper:2012_jumping"` — get BibTeX entry from BibTeX key
- `path2key "Vesper et al. - 2012 - Are You Ready to Jump Predictive Mechanisms vesper2012_jumping.md"` — get BibTeX key from filename 
- `path2key "random-nonheuristic-name.md"` — check index fallback via `$PAPERS_DIR/bibtex-index.jsonl` if present
- `find-bib --author steward --year 2009 --title animal` — get a key from CSL-JSON
  - Default source: `BIB_JSON=$HOME/endnote/phd_biblio.json` (Pandoc CSL-JSON from your BibTeX). Use `--json` or `--cat` for JSON or BibTeX output.

**Note:** The tools `cite2md` and `cite2bib` accept either LaTeX-style citations (with `\citet{}`) or bare BibTeX keys. 

## Using find-bib
- Purpose: Quickly locate bibliography entries using substring filters without parsing `.bib` files.
- Common patterns:
  - Keys only (default): `find-bib --author butterfill --year 2022 --title motor`
  - Full BibTeX: `find-bib --author smith --cat`
  - BibTeX entry as JSON: `find-bib --abstract "joint action" --json`
  - Limit: `find-bib --author steward --limit 1`
- Flags are repeatable and AND across fields; repeated flags are OR within that field.
- Exit codes: 0 has results; 1 no matches; 2 usage/deps error.

Please check you can execute the shell commands `cite2md` and `cite2bib` to obtain info for the key `vesper:2012_jumping`.  Use their `--help` as needed.  **If you cannot execute these commands, stop immediately and report the error.**

## Searching sources with `rg-sources`
Behavior:
- Pass any ripgrep flags as usual

Usage examples:
- `rg-sources -n "bayesian prior"` — search all markdown with line numbers.
- `rg-sources -i -C2 "causal effect"` — case-insensitive with 2 lines context.
