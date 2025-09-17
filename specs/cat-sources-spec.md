# cat-sources — Safely read source files from PAPERS_DIR

A tiny, agent-friendly CLI to print the contents of Markdown source files located under `PAPERS_DIR`. It enables agents to open files listed by `fd-sources`/`rg-sources` even when they cannot directly access `$PAPERS_DIR` paths.

## Name & Purpose
- Command: `cat-sources`
- Goal: Given one or more relative paths under `$PAPERS_DIR`, or newline-delimited paths on stdin, print file contents in a safe, predictable way.
- Scope: Read-only, restricted to `$PAPERS_DIR` (default `$HOME/papers`). Rejects absolute and parent-directory paths.

## CLI
- `cat-sources [paths...]`
- With no positional args, reads newline-delimited paths from stdin (blank lines and lines starting with `#` are ignored).
- Flags:
  - `-h|--help` — print concise usage and exit 0.
  - `--headers` — print a header `==> path <==` before each file when more than one input path is provided.
  - `-n|--number` — add line numbers to output (reset per file).

## Behavior
- Validates `PAPERS_DIR` exists; `cd` into it to keep scope tight and output paths relative.
- Rejects inputs that are absolute (`/foo`) or that traverse parents (`..` in a path component).
- Treats inputs literally (no glob expansion). Discovery remains the job of `fd-sources`/`rg-sources`.
- Prints contents in the order received. Missing files are reported to stderr and skipped.
- Exit 0 if at least one file was printed; exit 1 if no files were printed; exit 2 for usage/config errors.

## Examples
- `fd-sources vesper2012_jumping | cat-sources`
- `rg-sources -l 'bayesian prior' | cat-sources`
- `fd-sources -i 'butterfill.*2019' | cat-sources --headers`
- `cite2md vesper:2012_jumping | cat-sources`

## Related Convenience Flags
- `fd-sources --cat` — equivalent to piping matches to `cat-sources`.
- `rg-sources --cat` — equivalent to `rg -l | sort -u | cat-sources` with existing scoping and type rules.

## Exit Codes
- 0: at least one file printed
- 1: no files printed (e.g., all inputs missing)
- 2: usage/config error (e.g., missing `PAPERS_DIR`, path escape attempt)

## Testing
- Rejects absolute and parent-directory paths.
- Prints known file content from `$PAPERS_DIR`.
- Reads paths from stdin; prints multiple files with `--headers`.
- `fd-sources --cat` and `rg-sources --cat` e2e cases return non-empty content for known fixtures.

