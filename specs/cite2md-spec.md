# cite2md — Resolve a citation/key to a Markdown fulltext path

Resolves one or more LaTeX-style citations or BibTeX keys to corresponding Markdown files in the local papers directory. Supports multiple inputs via positional args or stdin. Optionally prints file contents.

## Name & Purpose
- Command: `cite2md`
- Goal: Given `\citet{key}`, a `key` with colons, or a normalized `key` without colons, print the absolute Markdown file path, the file contents, or the first sentence.

## Configuration & Env Vars
- `PAPERS_DIR` (default: `$HOME/papers`)
  - Root of local fulltext sources.
- Index path (internal): `$PAPERS_DIR/bibtex-index.jsonl`
  - Newline‑delimited JSON objects with fields like `.key`, `.path`, `.filename`.

## Inputs
- Flags:
  - `--cat` — print file contents instead of path
  - `-h|--help` — help text
  - `--vs` — **human-only**: open the resolved file in Visual Studio Code (runs `code <path>`); mutually exclusive with other output flags and hidden from `--help`
  - `--vsi` — **human-only**: open the resolved file in Visual Studio Code Insiders (runs `code-insiders <path>`); mutually exclusive with other output flags and hidden from `--help`
  - `-r|--reveal` — **human-only**: reveal the resolved file in Finder (runs `open -R <path>`); mutually exclusive with other output flags and hidden from `--help`
- Positional: one or more `citation-or-key` tokens; if none provided, read newline-delimited tokens from stdin (blank lines and lines starting with `#` are ignored)
  - LaTeX style: e.g., `"\citet{vesper:2012_jumping}"` (extracts inner `{…}`)
  - Key with colons: e.g., `vesper:2012_jumping`
  - Normalized key: e.g., `vesper2012_jumping`

## Resolution Strategy
1) Parse key and derive `normkey` (remove `:` from key).
2) Direct filename lookup using `fd` under `$PAPERS_DIR`:
   - Regex: `${normkey}\.md$`; take the first match.
3) Fallback to index (`$PAPERS_DIR/bibtex-index.jsonl`) if present:
   - First try `select(.key == key) | .path // .filename`.
   - If not found, try normalized match: `select((.key|gsub(":";"")) == normkey) | .path // .filename`.
   - Resolve to `$PAPERS_DIR/<rel>` and ensure the file exists.
4) If no file is found, exit non‑zero with a concise error including both forms of the key.

## Output Modes
- Default (no flag): print absolute file path(s), one per resolved input.
- `--cat`: print the entire file(s) to stdout, concatenated.
- `--vs`: open the resolved file in VS Code; still writes the resolved path to stdout for chaining.
- `--vsi`: open the resolved file in VS Code Insiders; still writes the resolved path to stdout for chaining.
- `-r|--reveal`: reveal the resolved file in Finder via `open -R`; does not emit the path if the reveal succeeds.

## Exit Codes
- 0: at least one input resolved and emitted
- 1: none resolved (all missing)
- 2: usage error (e.g., no input keys provided)

## Dependencies
- Required: `fd`, `jq`, `sed`, `awk`

## Missing Key Handling
- For any input that cannot be resolved, prints a standardized message to stderr:
  - `MISSING cite2md: <key> (normalized: <normkey>) in <PAPERS_DIR>`
- Also appends the missing key (verbatim) to a local file `missing-fulltext.txt` in the current working directory (one key per line). The file is created if it does not exist.

## Examples
- Path from LaTeX citation:
  - `cite2md "\citet{vesper:2012_jumping}"`
- Print file contents:
  - `cite2md --cat vesper:2012_jumping | sed -n '1,10p'`
- Open directly in VS Code (hidden human-only flag):
  - `cite2md --vs vesper2012_jumping`
- Reveal the file in Finder to move or inspect it:
  - `cite2md --reveal vesper:2012_jumping`
