## Tools for Searching, Reading and Citing Sources
Use these CLI tools to locate sources, read full text, and fetch citations. Tools are on your PATH; call them directly (no `./` required). Inputs can be LaTeX-style citations (e.g., `\citet{key}`) or bare BibTeX keys (e.g., `author:year_title`).

### The Tools
- cite2md — print a Markdown fulltext path or content for a citation/key
  - Use `--cat` to stream content for a single key.
- cite2abs — print an abstract path or content for a citation/key
- draft2keys — extract keys from a draft (prints unique keys)
- cite2bib — print the corresponding BibTeX entry for a citation/key
- path2key — infer the BibTeX key from a filename or path
- find-bib — field-filter the complete canonical bibliography catalogue; output citation keys or BibTeX
- rg-sources — ripgrep search across Markdown fulltext of available sources
- rg-abstracts — ripgrep search across Markdown abstracts
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
- Discover catalogue records by precise fields
  - `find-bib --author smith | sed -n '1p'`
  - Different fields are AND; repeated values of one field are OR.
  - `find-bib` searches the complete canonical catalogue, including secondary-only records; primary metadata wins for shared citation keys.
- Fetch a BibTeX entry
  - `cite2bib vesper:2012_jumping`
  - Or filter and emit: `find-bib --author agrillo --year 2017 --cat`
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

### Discovery-only abstract triage
For finding candidate sources, you may search and read abstracts before reading full text.

- Search catalogue abstract metadata:
  - `find-bib --abstract "joint action"`
  - This can find secondary-only catalogue records that do not yet have a local abstract/fulltext file.
- Search local Markdown abstracts:
  - `rg-abstracts -l -i "joint action"`
  - `rg-abstracts -i -C2 "motor representation"`
- Read one local abstract:
  - `cite2abs --cat butterfill:2019_goals`

Use abstracts only to identify promising sources. Do not use abstracts to fact-check a draft or to report what a paper argues. Abstracts should not usually be quoted. For those tasks, read the full text with `cite2md --cat`. Sometimes abstracts are missing even though the full text of a source exists.

- Read files found by other tools
  - From `fd-sources`: `fd-sources vesper2012_jumping | cat-sources`
  - From `rg-sources`: `rg-sources -l 'bayesian prior' | cat-sources`
  - From a citation/key: `cite2md vesper:2012_jumping | cat-sources`
  - From a draft: `draft2keys draft.md | cite2md --cat`

### Notes
- Prefer `cite2md`/`cite2bib` to move between citations/keys and fulltext/BibTeX quickly when reviewing drafts.
- Use `find-bib` for precise author/year/title/DOI/abstract field filtering across the complete canonical catalogue. It is not a fuzzy relevance ranker.
- A valid `find-bib` result does not imply that BibTeX, Markdown, PDF, or a local abstract exists; catalogue membership and local artifacts are separate.
- Use `rg-abstracts`/`cite2abs` only for discovery triage; use full text for evidence.
- `path2key` helps when you only have a filename and need the citation key.
- For options and flags, run `--help` on any command.
