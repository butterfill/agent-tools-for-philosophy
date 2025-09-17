# keys2cat — Read multiple sources by keys (Proposed)

Purpose
- Batch resolve citations/keys to fulltext and stream content; stdin-first design for composition with other tools.

CLI
- `keys2cat [--headers] [keys...]`
- With no args, reads keys/citations from stdin. Lines starting with `#` or blank lines are ignored.
- Help: `-h|--help`

Behavior
- For each input token (key or LaTeX citation form), resolve via `cite2md` to a path and stream via `cat-sources`.
- Rejects tokens that do not resolve (print error to stderr and append to `keys2cat-missing-keys.log`, continue to next).

Exit Codes
- 0: at least one file printed
- 1: no valid keys resolved/printed
- 2: usage/config error (e.g., missing dependencies)

Dependencies
- `cite2md`, `cat-sources`.

Examples
- `find-bib --abstract "joint action" --limit 5 | keys2cat`
- `keys2cat vesper:2012_jumping butterfill:2019_goals`

