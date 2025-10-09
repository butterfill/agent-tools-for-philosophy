# cite2pdf — Resolve a citation/key to a PDF fulltext path

Resolves one or more LaTeX-style citations or BibTeX keys to corresponding PDF files in the local papers directory. Supports multiple inputs via positional args or stdin. Designed for human operators; can optionally open the resolved PDF.

## Name & Purpose
- Command: `cite2pdf`
- Goal: Given `\citet{key}`, a `key` with colons, or a normalized `key` without colons, print the absolute PDF file path or open the PDF in the default viewer.

## Configuration & Env Vars
- `PAPERS_DIR` (default: `$HOME/papers`)
  - Root of local fulltext sources.

## Inputs
- Flags:
  - `-o|--open` — **human-only**: open the resolved PDF in the default system viewer (e.g., `open` on macOS, `xdg-open` on Linux); still emits the resolved path to stdout on success.
  - `-h|--help` — help text
  - `-r` / `--reveal` : open Finder with the file revealed (same as `open -R "$(cite2md [key])"`); mutually exclusive with other output flags
- Positional: one or more `citation-or-key` tokens; if none provided, read newline-delimited tokens from stdin (blank lines and lines starting with `#` are ignored)
  - LaTeX style: e.g., `"\citet{vesper:2012_jumping}"` (extracts inner `{…}`)
  - Key with colons: e.g., `vesper:2012_jumping`
  - Normalized key: e.g., `vesper2012_jumping`

## Resolution Strategy
1) Parse key and derive `normkey` (remove `:` from key).
2) Direct filename lookup using `fd` under `$PAPERS_DIR`:
   - Regex: `${normkey}\.pdf$`; take the first match.
3) If no direct match, execute `cite2md` for the same key. If that resolves to `<path>.md`, replace `.md` with `.pdf` and verify that file exists.
4) If no file is found, exit non-zero with a concise error including both the original key and `normkey`.

## Output Modes
- Default (no flag): print absolute PDF path(s), one per resolved input.
- `-o|--open`: open the PDF in the default viewer; still prints the resolved path for confirmation.

## Exit Codes
- 0: at least one input resolved and emitted
- 1: none resolved (all missing)
- 2: usage error (e.g., no input keys provided or mutually exclusive flags)

## Dependencies
- Required: `fd`, `cite2md`, default system opener (`open`/`xdg-open`/`start`)

## Missing Key Handling
- For any input that cannot be resolved, prints a standardized message to stderr:
  - `MISSING cite2pdf: <key> (normalized: <normkey>) in <PAPERS_DIR>`
- Does not create or update tracking files; responsibility for logging missing PDFs rests with callers.

## Examples
- Path from LaTeX citation:
  - `cite2pdf "\citet{vesper:2012_jumping}"`
- Open PDF immediately in default viewer:
  - `cite2pdf --open vesper:2012_jumping`
