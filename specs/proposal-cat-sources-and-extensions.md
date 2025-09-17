# Proposal: Easy Reading of Source Files (cat-sources) and Convenience Flags

Problem
- `rg-sources` and `fd-sources` currently print filenames only. In agent sandboxes, direct `cat` of `$PAPERS_DIR/<path>` is not permitted, so agents cannot open files after discovery.
- We want a very simple, consistent way for agents to read the full text of sources without granting them broad filesystem access.

Solution Overview
- Add a tiny, scoped reader CLI: `cat-sources` that reads files only from `$PAPERS_DIR`.
- Add an optional `--cat` convenience flag to `fd-sources` and `rg-sources` to stream matched files’ contents directly, avoiding pipelines when desired.
- Keep defaults unchanged; discovery tools still list names unless `--cat` is explicitly used.

## New Tool: cat-sources — Read source files from PAPERS_DIR

Name & Purpose
- Command: `cat-sources`
- Goal: Print the contents of one or more Markdown source files located under `$PAPERS_DIR`.
- Scope: Enforces reading only within `$PAPERS_DIR` (default: `$HOME/papers`). Rejects absolute and parent-directory paths.

CLI
- `cat-sources [paths...]`
- `cat-sources` (no args) reads newline-delimited paths from stdin.
- `-h|--help` — print concise usage and exit.
- Optional quality-of-life flags (minimal set to keep it simple):
  - `--headers` — print `==> path <==` before each file when more than one input path is provided (off by default).
  - `-n|--number` — add line numbers to output (delegates to `nl` if available; otherwise fallback implementation).

Behavior
- `cd "$PAPERS_DIR"` and read each path relative to it.
- Inputs that are absolute paths or that traverse parents (e.g., `../x`, `a/../../b`) are rejected with exit code 2.
- Missing files are reported to stderr but do not crash the entire run; overall exit code is 1 if any requested file is missing and nothing was printed.
- Reads stdin when no positional paths are provided; blank lines and comments starting with `#` are ignored.
- No glob expansion; paths are treated literally for predictability. Discovery remains the job of `fd-sources`/`rg-sources`.

Exit Codes
- 0: at least one file was printed successfully
- 1: no files printed (e.g., all inputs missing)
- 2: usage/config error (e.g., missing `PAPERS_DIR`, path escape attempt)

Examples
- From filename search: `fd-sources vesper2012_jumping | cat-sources`
- From ripgrep search: `rg-sources -l 'bayesian prior' | cat-sources`
- With headers: `fd-sources -i 'butterfill.*2019' | cat-sources --headers`
- From a specific relative path: `cat-sources notes/vesper2012_jumping.md`
- From a key via existing tool: `cite2md vesper:2012_jumping | cat-sources`

Rationale
- Maintains strong scoping while enabling agents to read content easily.
- Keeps the mental model simple: discovery → read.

## Convenience Extensions

### fd-sources — add `--cat`

Intent
- When `--cat` is present, stream contents of matched files via `cat-sources`.

Semantics
- Equivalent to: `fd [args...] | cat-sources`
- Defaults to `.md` and `.mdx` unless `--extension/-e` provided (unchanged).
- Still rejects absolute or parent-directory path arguments (unchanged).
- Exit codes:
  - 0 if any content printed
  - 1 if no files matched
  - 2 usage/config error (e.g., missing `fd`, missing `PAPERS_DIR`)

Examples
- `fd-sources vesper2012_jumping --cat`
- `fd-sources -i 'butterfill.*2019' --cat`

### rg-sources — add `--cat`

Intent
- When `--cat` is present, stream contents of unique files that match the `rg` search.

Semantics
- Equivalent to: `rg -l [args...] | sort -u | cat-sources`
- Default type-filtering and path safety rules remain unchanged.
- If the caller also passes `-l`, behavior is the same; duplicates removed.
- Exit codes:
  - 0 if any content printed
  - 1 if no files matched
  - 2 usage/config error (e.g., missing `PAPERS_DIR`)

Examples
- `rg-sources -i -C1 'causal effect' --cat`
- `rg-sources --type md 'bayesian prior' --cat`

## Agent UX Patterns
- Discover then read (pipeline):
  - `fd-sources <pattern> | cat-sources`
  - `rg-sources -l <pattern> | cat-sources`
- One-shot read:
  - `fd-sources <pattern> --cat`
  - `rg-sources <pattern> --cat`
- From citation/key to full text:
  - `cite2md <key|\citet{key}> | cat-sources`

## Security & Scope
- All read operations are restricted to `$PAPERS_DIR` via `cd`.
- Absolute paths and parent-directory traversals are rejected.
- No network or external I/O is introduced.

## Testing (outline)
- cat-sources unit tests:
  - rejects absolute and `..` paths.
  - prints content for a known relative path.
  - reads stdin paths and handles multiple files.
- fd-sources e2e:
  - `--cat` returns non-empty content for a known filename.
  - still rejects absolute path args.
- rg-sources e2e:
  - `--cat` returns non-empty content for a known search term.
  - still rejects absolute path args.

## Documentation Updates
- instructions.md: add a short “Read files” section featuring the three common flows above.
- README “Install” remains unchanged (no new external deps).

## Alternatives Considered
- Emitting absolute paths from discovery tools: does not help in sandboxes without access to `$PAPERS_DIR`.
- Adding a JSON content mode to discovery tools: heavier to parse and overkill for the primary need (read files).
- A pager tool: can be added later (e.g., `view-sources`), but `cat-sources` keeps the first step minimal.

