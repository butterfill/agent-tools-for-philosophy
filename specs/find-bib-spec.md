# find-bib — Search entries in Pandoc CSL-JSON

A small, agent-friendly CLI to locate bibliography entries by case‑insensitive substring filters over common fields and return keys or full entries. Uses a fast Pandoc‑converted CSL‑JSON file (converted from the BibTeX) instead of parsing a `.bib` file.

## Name & Purpose
- Command: `find-bib`
- Goal: Given field filters (author/year/doi/title/abstract), print matching BibTeX keys or entries resolved from a single CSL‑JSON file produced by Pandoc from the canonical BibTeX.

## Configuration & Env Vars
- `BIB_JSON` (default: `$HOME/endnote/phd_biblio.json`)
  - Primary data source (CSL‑JSON from Pandoc). No CLI to override (keep agent setup simple). Note: the `endnote` folder name is historical only and does not imply EndNote format.
- `BIB_FILE` (optional): used only when emitting BibTeX via `--cat`, defaulting to `cite2bib`’s default (`$HOME/endnote/phd_biblio.bib`).
- No use of `PAPERS_DIR` (this tool does not read Markdown).

## Inputs (CLI)
- Field filters (repeatable; case-insensitive substring match):
  - `--author "text"`
  - `--year "YYYY"`
  - `--doi "text"`
  - `--title "text"`
  - `--abstract "text"`
- Output control:
  - `--cat` — print full BibTeX entries by resolving keys via `cite2bib` (default prints keys, one per line)
- Help:
  - `-h`, `--help`

## JSON Schema Assumptions
- The file at `BIB_JSON` is CSL‑JSON as produced by Pandoc (`-t csljson`). Typical structure:
  - A JSON array of items (preferred/typical), or
  - A JSON object with an `items` array (accept as a fallback).
- Each item contains at least a unique citation key and common bibliographic fields. Supported field mappings for matching:
  - key: `.id` (primary CSL‑JSON key). Also accept `.ID` or `.key` if present.
  - author(s): `.author` is an array of name objects with `.family` and `.given`. Join names as "Family, Given" for matching; also handle `.author` as a string if encountered.
  - title: `.title` (string).
  - year: derived from `.issued["date-parts"][0][0]` if present, else from `.issued.literal` by extracting a 4‑digit year.
  - doi: `.DOI` (CSL capitalization) or `.doi`.
  - abstract: `.abstract`.

## Matching Semantics
- AND across different fields: all specified fields must match for an entry to qualify.
- OR within the same field: if a field flag is repeated, any of its values may match.
- Substring, case-insensitive match after simple normalization (lowercase, collapse spaces; braces are ignored if present in source strings).
- Missing field in an entry fails that field’s filter.

## Output
- Default: keys only (one per line), no extra logging.
- `--cat`: for each matched key, call `cite2bib <key>` and print the resulting BibTeX entry. Entries are separated by a blank line (as produced by `cite2bib`).

## Exit Codes
- 0: at least one match printed
- 1: no matches
- 2: usage/config error (e.g., missing or unreadable `BIB_JSON`, missing `cite2bib` when `--cat` is used)

## Dependencies
- Required: `jq` (for fast, robust JSON filtering) or an equivalent standard‑library implementation if not using shell.
- Optional for `--cat`: `cite2bib` on `PATH` (reads `BIB_FILE`).
- No Python runtime or `bibtexparser` dependency.

## Behavior Details
- Load entries from `BIB_JSON` (array or `records` property).
- Build normalized strings for fields to support case‑insensitive substring filtering.
- Iterate once over entries; short‑circuit when `--limit` is reached.
- Keep stdout reserved for results; send diagnostics/errors to stderr.
- Performance: avoid full BibTeX parsing; operate on JSON only. Resolving `--cat` delegates per‑key to `cite2bib` for correctness and consistency with other tools.

## Consistency With Existing Tools
- Mirrors conventions in `cite2bib` / `cite2md`:
  - Simple `--help`, clear exit codes, env var config with safe defaults.
  - No extra noise on success.
  - Fail fast on missing inputs/resources.

## Examples
- Find key from field filters:
  - `find-bib --author steward --year 2009 --title "animal agency"`
  - Output: `steward:2009_animal`
- Abstract/topic search:
  - `find-bib --abstract "joint action" --abstract motor`
- Print BibTeX entries instead of keys:
  - `find-bib --author agrillo --year 2017 --cat`
- Print raw JSON entries instead of keys:
  - `find-bib --author agrillo --year 2017 --json`

## Non-Goals
- No Markdown/source searching, no network, no DOI resolution.
- No CLI option to change `BIB_JSON` (adjust via env or source).
