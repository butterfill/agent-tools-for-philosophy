These are CLI tools created for use by AI coding/analysis agents (codex, Claude Code, rovodev, etc.) focused on philosophical analysis: reading, searching, quoting, and citing.

## Goals
- Keep mental model simple: discover → read → quote/cite.
- Reduce friction in common scenarios

## Scenarios
- an agent is reviewing a draft which contains BibTeX citations. The agent’s task is to check that the draft provides an accurate, insightful and fair characterisation of the sources it cites.

- an agent is given a task and a list of BibTeX keys. The agent must read the source corresponding to each key to complete the task.

- an agent is reviewing a draft and is tasked to find potentially relevant academic sources.

- an agent is reviewing a draft which contains ordinary citations like "(Steward, 2009)". It is asked to (i) find the fulltext of sources cited where available and use those in fact-checking the draft; and (ii) produce a list for which the fulltext is not available.

- an agent is asked to find BibTeX key for full text citation like "Steward, H. (2009). Animal Agency. Inquiry, 52(3), 217–231." 

- an agent wants to find sources that are relevant to understanding motor processes in joint action. 

- an agent is given a document with some missing citations. It should identify which citations to add to the document.


## `instructions.md`
This file is for the agent. It instructs the agent on how to use each tool.

New: agents can now read source files directly
- Use `cat-sources` to print contents of files under `$PAPERS_DIR`.
- Discovery tools support one-shot reading:
  - `fd-sources --cat <pattern>` streams matched files.
  - `rg-sources --cat <pattern>` streams content of files matching the search.

## Install (for developers)
- Ensure `jq` is installed (required for `find-bib`)
- Ensure the `$BIB_FILE` and `$PAPERS_DIR` exist on the host (defaults to where you’d expect them to be; if they are not there, export these env vars)
- Run `./install.sh` to copy executable tools into a user bin.

## Testing
- Run individual test scripts in `tests/` directly:
  - `bash tests/find-bib.csljson.test.sh`
  - `bash tests/path2key.test.sh`
  - `bash tests/cat-sources.test.sh`
  - `bash tests/fd-sources-cat.e2e.test.sh`
  - `bash tests/rg-sources-cat.e2e.test.sh`
- Tests rely on local scripts in this directory being executable (no `./` prefix is required if installed on PATH, but tests call them via `./`).
- The `find-bib` tests use a small CSL‑JSON fixture at `tests/fixtures/phd_biblio.json` and a small BibTeX fixture at `tests/fixtures/sample.bib` for `--cat` integration with `cite2bib`.

## Contributing Tools (for developers)
- Location and naming
  - Put new tools in this directory and make them executable.
  - Use a clear, short command name (hyphenated if necessary). Extensions should not be used.
- Baseline script pattern
  - Start Bash tools with `#!/usr/bin/env bash` and `set -euo pipefail`.
  - Provide a `--help` flag that prints concise usage and exit codes.
  - Return consistent exit codes (e.g., 0 success; 1 not found; 2 usage/config error).
- Environment and scope
  - Prefer environment variables for configurable roots (e.g., `PAPERS_DIR` with a safe default).
  - Check environment variables already in use before requiring any new ones.
  - If a tool must access outside the repo, scope carefully and validate inputs (e.g., reject absolute `paths`).
- Dependencies and conventions
  - Prefer `fd` for file discovery, `rg` for text search, `ast-grep` for syntax-aware matching, `jq`/`yq` for JSON/YAML.
  - Fail fast with clear error messages when a required dependency is missing.
- Output discipline
  - Keep stdout for the tool’s primary data. Send diagnostics to stderr.
  - Avoid extra wrapper noise; let underlying tools (e.g., `rg`) control formatting.
- Documentation hook
  - After adding a tool, add a short entry to `instructions.md` (agent-facing). Avoid duplicating `--help` text.
- Testing
  - Provide a minimal smoke test or example commands. Add test scripts under `tests/`.
