# cite2bib — Resolve a citation/key to a BibTeX entry

Resolves a LaTeX-style citation or BibTeX key to the corresponding BibTeX entry by scanning a local `.bib` file. Prefers exact key matches and falls back to matching a colon‑stripped, normalized key.

## Name & Purpose
- Command: `cite2bib`
- Goal: Given `\citet{key}`, a `key` with colons, or a normalized `key` without colons, print the full BibTeX entry.

## Configuration & Env Vars
- `BIB_FILE` (default: `$HOME/endnote/phd_biblio.bib`)
  - Path to the canonical BibTeX file to scan.
- `CITE2BIB_AWK_IMPL` (optional): force awk implementation used for normalized fallback.
  - Values: `awk` or `gawk`. Defaults to `gawk` if available, else `awk`.

## Inputs
- Positional: `citation-or-key`
  - LaTeX style: e.g., `"\citet{vesper:2012_jumping}"` (extracts the text inside `{…}`)
  - Exact BibTeX key: e.g., `vesper:2012_jumping`
  - Normalized key (no colons): e.g., `vesper2012_jumping`
- Help: `-h|--help`

## Behavior
1) Parse key:
   - If input contains `{…}`, extract inner text as the key; else use input as provided.
   - Compute `normkey` by removing all `:` from the key.
2) Validate `BIB_FILE` exists; otherwise exit 1.
3) Exact match fast path:
   - Locate a line matching `^[[:space:]]*@[A-Za-z]+\{<key>,` and record its line number.
   - Print from that line to the end of the entry by tracking brace depth until it closes.
4) Normalized fallback:
   - Scan entries; for each `@type{key,`, strip `:` from `key` and compare to `normkey`.
   - On a match, print the entry as above.
5) On failure, print a succinct not‑found message to stderr, including the normalized key.

## Output
- Success: prints the BibTeX entry only, unchanged.
- Failure: no stdout; error to stderr.

## Exit Codes
- 0: success (entry printed)
- 1: not found or `BIB_FILE` missing
- 2: usage error (e.g., missing input)

## Dependencies
- Required: `rg`, `awk` (or `gawk`), `sed`

## Examples
- Exact key:
  - `cite2bib vesper:2012_jumping | rg '^@'`
- Normalized key:
  - `cite2bib vesper2012_jumping > vesper.bib`
- LaTeX citation form:
  - `cite2bib "\citet{alter:2009_uniting}" | rg doi`

## Missing Key Handling
- On failure to locate an entry, prints standardized message to stderr:
  - `MISSING cite2bib: <key> (normalized: <normkey>) in <BIB_FILE>`
- Also appends the missing key (verbatim) to a local file `missing-keys.txt` in the current working directory (one key per line).
