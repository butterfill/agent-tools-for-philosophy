# find-bib — Search entries in a BibTeX file

A small, agent-friendly CLI to locate BibTeX entries by case‑insensitive substring filters over common fields and return keys or full entries.

## Name & Purpose
- Command: `find-bib`
- Goal: Given field filters (author/year/doi/title/abstract), print matching BibTeX keys or full entries from a single BibTeX file.

## Configuration & Env Vars
- `BIB_FILE` (default: `$HOME/endnote/phd_biblio.bib`)
  - Mirrors `cite2bib.sh` behavior; no CLI to override (keep agent setup simple).
- No use of `PAPERS_DIR` (this tool does not read Markdown).

## Inputs (CLI)
- Field filters (repeatable; case-insensitive substring match):
  - `--author "text"`
  - `--year "YYYY"`
  - `--doi "text"`
  - `--title "text"`
  - `--abstract "text"`
- Output control:
  - `--cat` — print full BibTeX entries (default prints keys, one per line)
  - `--limit N` — limit number of printed results (no limit by default)
- Help:
  - `-h`, `--help`

## Matching Semantics
- AND across different fields: all specified fields must match for an entry to qualify.
- OR within the same field: if a field flag is repeated, any of its values may match.
- Substring, case-insensitive match after simple normalization (lowercase, collapse spaces).
- Missing field in an entry fails that field’s filter.

## Output
- Default: keys only (one per line), no extra logging.
- `--cat`: print full BibTeX entries (verbatim as parsed/serialized), separated by a blank line.

## Exit Codes
- 0: at least one match printed
- 1: no matches
- 2: usage/config/dependency error (e.g., missing `BIB_FILE`, missing Python deps)

## Dependencies
- Required: `python3`
- Python packages: `bibtexparser`
  - On ImportError, print a clear hint to install (e.g., `pip install bibtexparser`) and exit 2.

## Behavior Details
- Parses the BibTeX using `bibtexparser` to robustly handle multiline fields, braces/quotes, and encodings.
- For `--cat`, re-serialize the matched entries via `bibtexparser` (preserve key and core fields; exact whitespace may differ from source).
- Keep stdout reserved for results; send diagnostics/errors to stderr.
- Performance: iterate once over entries; short-circuit when `--limit` reached.

## Consistency With Existing Tools
- Mirrors conventions in `cite2bib.sh` / `cite2md.sh`:
  - Simple `--help`, clear exit codes, env var config with safe defaults.
  - No extra noise on success.
  - Fail fast on missing inputs/resources.

## Examples
- Find key from full citation (Scenario 1):
  - `find-bib --author steward --year 2009 --title "animal agency"`
  - Output: `steward:2009_animal`
- Abstract/topic search:
  - `find-bib --abstract "joint action" --abstract motor`
- Print entries instead of keys:
  - `find-bib --author agrillo --year 2017 --cat`

## Non-Goals
- No Markdown/source searching, no network, no DOI resolution.
- No CLI option to change `BIB_FILE` (adjust via env or source).

