# path2key.sh — Resolve a file path to a BibTeX key

A tiny CLI to infer and validate a BibTeX key from a file path located in (or related to) your papers directory. It prefers an explicit mapping in the index if available, and otherwise infers the key from the filename pattern. It never returns a key without first validating that the key exists via `cite2bib.sh`.

## Name & Purpose
- Command: `path2key.sh`
- Goal: Given a file path (absolute, relative, or just a basename), return the BibTeX key for the cited work, using:
  1) A filename heuristic where the last word of the filename is a normalized key (colons removed) — e.g., `vesper2012_jumping` corresponds to `vesper:2012_jumping`.
  2) `$PAPERS_DIR/bibtex-index.jsonl` (if available) as a fallback.
- Guarantee: Do not emit a key unless `cite2bib.sh` can resolve it (exit 0).

## Inputs
- Positional: `path` — may be any of:
  - Absolute path anywhere on the filesystem (may or may not be under `$PAPERS_DIR`).
  - Path relative to `$PAPERS_DIR` (e.g., `notes/some topic/sinigaglia2022_motor.md`).
  - Bare filename or basename with or without extension (e.g., `sinigaglia2022_motor.md`, `sinigaglia2022_motor`).

### Flags
- `-h|--help` — help text.

## Behavior
- Normalize the input and robustly handle paths that include all, part, or none of `$PAPERS_DIR`.
- Determine `basename` and `stem` (basename without extension). If `basename` contains whitespace, the "last word" is the last whitespace-delimited token of `stem`.
- Infer the key from the last word of `stem` by inserting a colon between the author surname and the 4-digit year.
- If that fails, try index mapping (if available) from `.filename` or the basename of `.path` to `key`.
- Validate any candidate key by calling `cite2bib.sh <candidate>` and only emit a key if that returns exit code 0.
- On success, print the BibTeX key to stdout with no extra text.
- On failure, exit non-zero with a clear error message to stderr.

## Resolution Strategy

1) Index lookup:
   - Load `$INDEX_FILE` (`$PAPERS_DIR/bibtex-index.jsonl`).
   - Candidates (in order):
     - Match `.filename == basename` (exact string equality).
     - If `.path` is present, match `basename(.path) == basename`.
   - If a unique `key` is found, validate it via `cite2bib.sh`. On success, emit it.

2) Filename heuristic:
   - Extract `stem` (basename without extension).
   - Determine the last word token `last_word`:
     - If `stem` contains whitespace, split on whitespace and take the last token.
     - Else use `stem` entire.
   - Treat `last_word` as a normalized key with colons removed (e.g., `vesper2012_jumping`).
   - Reinsert a colon immediately before the first 4-digit year:
     - Regex: `^([A-Za-z][A-Za-z0-9-]*?)(19|20)\d\d(.*)$` → candidate key = `\1:\2\d\d\3`
     - Preserve original casing of `\1` and the remainder; do not downcase.
   - Try validation via `cite2bib.sh` with the colon-inserted candidate.
   - If that fails, try validation with the non-colon version (some keys may be stored without a colon, though uncommon).
   - Optional robustness (for mixed-case legacy keys like `Butterfill:2012fk`):
     - If both attempts fail, perform a case-insensitive discovery pass over `BIB_FILE` to find the real key whose colon-stripped form equals `last_word` (ignoring case). If found, validate the discovered key via `cite2bib.sh` and emit on success.

3) If all attempts fail: exit 1 with a message like `path2key.sh: could not resolve a BibTeX key from: <path>`.

## Environment
- `PAPERS_DIR`: default `$HOME/papers`.
- `INDEX_FILE`: default `$PAPERS_DIR/bibtex-index.jsonl`.
- `BIB_FILE`: indirectly used by `cite2bib.sh` for validation (default there is `$HOME/endnote/phd_biblio.bib`).

## Dependencies
- `jq` (for index lookups).
- `cite2bib.sh` (for key validation; must be on `PATH`).
- Standard shell utilities: `basename`, `sed`, `awk`, `rg` (optional for the robustness pass).

## Output
- Success: print the BibTeX key only, to stdout. Example: `sinigaglia:2022_motor`
- Failure: no stdout; diagnostic to stderr.

## Exit Codes
- 0: success (key printed)
- 1: not found / could not validate key
- 2: usage/configuration error (e.g., missing `cite2bib.sh`, invalid `--prefer` value)

## Examples
- `path2key.sh "$HOME/papers/joint action notes/sinigaglia2022_motor.md"` → `sinigaglia:2022_motor`
- `path2key.sh "notes/some paper vesper2012_jumping.md"` → `vesper:2012_jumping`
- `path2key.sh "Butterfill2012fk.md"` → `Butterfill:2012fk` (via heuristic + robustness pass)
- `PAPERS_DIR=~/papers path2key.sh "~/papers/agency/butterfill2019_goals.md"` → `butterfill:2019_goals`

## Notes & Edge Cases
- The filename heuristic assumes the "last word" of the filename encodes the normalized key (colons removed). This mirrors existing conventions where files end with `<normalized-key>.md`.
- If the index provides multiple entries for the same basename, pick the first but still validate via `cite2bib.sh`.
- If validation fails due to casing mismatches in legacy keys, the optional robustness step uses a case-insensitive scan to discover the actual key, then re-validates with `cite2bib.sh` before emitting.
