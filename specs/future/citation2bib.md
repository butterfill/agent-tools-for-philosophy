# citation2bib.sh — Resolve citation text to BibTeX

A CLI for converting a bibliographic citation string (or any text snippet containing a citation) into a BibTeX entry, favoring local results and working smoothly for agent tooling.

## Name & Purpose
- Command: `citation2bib.sh` (resolves citation text → BibTeX)
- Goal: Given a citation in free text or a full reference line, return the best BibTeX entry from local `.bib` files; optionally fall back to online services (DOI, arXiv, etc.) if not found locally.

## Inputs
- Positional: `citation-text` (optional; if omitted, read from stdin)
- `--file PATH`: read citation text from a file
- Optional field overrides (to improve matching if known):
  - `--doi DOI`, `--arxiv ID`, `--isbn ISBN`
  - `--title "Title"`, `--author "Surname[, Given]"`, `--year YYYY`
- `--bib PATH`: add/override a `.bib` file to search (repeatable)
- `--online/--no-online`: allow/deny network lookups (default: online allowed but local-first)

## Behavior
- Local-first resolution; online only if local search yields nothing or low confidence.
- Searches for BibTeX entries in `.bib` files under a bib root:
  - `BIB_DIR` (if set), else all `*.bib` under `PAPERS_DIR` (default `$HOME/papers`).
- Accepts citation text from arg, file, or stdin; extracts identifiers and metadata heuristically.
- Returns the best match; supports listing top candidates.

## Matching Strategy
1) Extract identifiers from text:
   - DOI: `10.\d{4,9}/\S+`
   - arXiv: `arXiv:\d{4}\.\d{4,5}` or legacy forms
   - ISBN-10/13 and URLs
2) Local search in `.bib` (via `rg`):
   - Exact identifier match: look for `doi = {...}`, `eprint = {...}`/`arxivId = {...}`, `isbn = {...}`.
     - Scoring: DOI +60, arXiv +40, ISBN +30 (high confidence)
   - Title/author/year heuristic when no identifiers:
     - Normalize text (lowercase, strip punctuation, collapse whitespace).
     - Derive candidate title tokens (>=4 chars), first author surname, year.
     - Search for combinations of `title =` tokens, `author =` surname, and `year = YYYY`.
     - Score: token overlap (+4 each up to +20), surname (+10), year (+5). Threshold e.g., ≥30 to auto-accept.
3) Online fallback (if enabled):
   - DOI → fetch BibTeX via content negotiation (doi.org)
   - arXiv → fetch arXiv export BibTeX
   - No identifiers → query Crossref by title/author/year and select highest score
- Deduplicate across files; prefer entries under `BIB_DIR` or standard bib files.

## Output
- Default: print the full BibTeX entry to stdout.
- `--key`: print the BibTeX key (local only). With online-only data, print nothing unless `--gen-key`.
- `--gen-key`: when only online data exists, generate a filesystem-safe key (e.g., `surnameYYYY_snakeTitleFirstWord`).
- `--json`: structured JSON including:
  - `source`: "local" | "online"
  - `confidence`: 0–100
  - `key`, `bibtex`, `bibfile` (path)
  - `match`: `{ method, identifiers, title_tokens, score_breakdown }`
- `--list N`: show top-N candidates (default 5) with compact info (confidence, key, title, file), no extra text.

## Exit Codes
- 0: success (at least one result printed)
- 1: not found / below confidence threshold and no `--list`
- 2: usage/config/dependency error (e.g., no readable `.bib`, network disabled but only online path available)

## CLI Flags
- Input: `--file PATH` (read from stdin if no positional text)
- Hints: `--doi`, `--arxiv`, `--isbn`, `--title`, `--author`, `--year`
- Scope: `--bib PATH` (repeatable), `--online`/`--no-online`
- Output: `--key`, `--gen-key`, `--json`, `--list [N]`
- Help: `-h`/`--help`

## Environment
- `PAPERS_DIR`: default `$HOME/papers`
- `BIB_DIR`: root directory to search for `.bib` files (default: `PAPERS_DIR`)
- `CITE_BIB_FILES`: optional colon-separated list of extra `.bib` files

## Dependencies
- Required: `rg`, `fd`, `sed`, `awk`
- Optional (online): `curl`, `jq`
- Behavior degrades gracefully if online disabled or missing tools

## Examples
- From a pasted reference:
  - `citation2bib.sh "Smith, J. (2019). Fast kernels... JMLR, 20(3), 1–20. doi:10.5555/12345"` → returns local BibTeX by DOI match
- From free text without identifiers:
  - `citation2bib.sh --year 2017 --author agrillo --title "numerical cognition fish"` → local heuristic match
- From stdin:
  - `pbpaste | citation2bib.sh --list 3` → print top 3 candidates
- Online fallback:
  - `citation2bib.sh "Doe, A. A Unified Theory of X (2021)" --online --json`

## Edge Cases
- Multiple strong matches: default returns highest confidence; `--list` to inspect others.
- Mismatched years: penalize but allow ±1 with reduced score.
- Non-ASCII: normalize Unicode (NFKD) for matching; preserve original in output.
- Missing `.bib`: exit 2 with a clear error suggesting setting `BIB_DIR` or adding files.

