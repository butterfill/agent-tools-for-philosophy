# rg-sources — ripgrep scoped to Markdown sources in PAPERS_DIR

A thin wrapper around ripgrep that confines searches to the local papers directory and, by default, to Markdown file types. Adds a convenience `--cat` mode to stream matched files via `cat-sources`.

## Name & Purpose
- Command: `rg-sources`
- Goal: Search within fulltext Markdown sources under `$PAPERS_DIR` using `rg`, with safe path scoping and sensible defaults for file types.

## Configuration & Env Vars
- `PAPERS_DIR` (default: `$HOME/papers`)
  - Search root. The tool `cd`s into this directory before invoking `rg`.

## CLI
- `rg-sources [rg-flags...] [--] [pattern] [paths...]`
- `rg-sources [rg-flags...] --cat [pattern]`
- Help: `-h|--help`

### Defaults & Pass‑through
- Passes flags and arguments through to `rg` except for type/glob controls.
- Always applies Markdown type filtering: injects `--type-add mdx:*.mdx -t md -t mdx` and does not allow overrides via `-t/-T/--type-*/--glob`.

### Safety & Scoping
- Rejects absolute paths and parent-directory traversals in positional `paths` and in option values for flags that take a path argument (e.g., `-f FILE`).
- Changes directory to `$PAPERS_DIR` prior to running the search so output paths are relative and scope is enforced.

### Convenience
- `--cat`: print contents of matched files instead of match lines.
  - Internally runs: `rg -l … | sort -u | cat-sources`.
  - Requires `cat-sources` on `PATH` or alongside the script.

## Output
- Default: identical to `rg` output for the given flags and pattern.
- With `--cat`: concatenated contents of matched files, in unspecified order (unique paths via `sort -u`).

## Exit Codes
- 0: success (at least one match; or `rg` succeeded with its semantics)
- 1: no matches (propagated from `rg` or `cat-sources` in `--cat` mode)
- 2: usage/config error (e.g., missing `PAPERS_DIR`, `cat-sources` not found for `--cat`, rejected absolute/parent path)

## Dependencies
- Required: `rg` (ripgrep)
- Optional for `--cat`: `cat-sources`

## Examples
- Search phrase with line numbers:
  - `rg-sources -n "bayesian prior"`
- Case-insensitive with one line of context:
  - `rg-sources -i -C1 "causal"`
- Stream fulltext for matches:
  - `rg-sources -i "joint action" --cat`
- Provide your own types (disables default md/mdx types):
  - `rg-sources -t markdown "predictive processing"`
