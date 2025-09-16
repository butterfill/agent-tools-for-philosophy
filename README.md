These are CLI tools created for use by agents (codex, rovodev, ...).

## `instructions.md`

This file is for the agent. It instructs the agent on how to use each tool.

## Contributing Tools (for developers)

- Location and naming
  - Put new tools in this `agent-tools/` directory and make them executable.
  - Use a clear, short command name (hyphenated). Extensions are optional.
- Baseline script pattern
  - Start Bash tools with `#!/usr/bin/env bash` and `set -euo pipefail`.
  - Provide a `--help` flag that prints concise usage and exit codes.
  - Return consistent exit codes (e.g., 0 success; 1 not found; 2 usage/config error).
- Environment and scope
  - Prefer environment variables for configurable roots (e.g., `PAPERS_DIR` with a safe default).
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
  - Provide a minimal smoke test or example commands. If useful, add small scripts under `agent-tools/tests/`.
