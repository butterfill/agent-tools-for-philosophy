Aim: enable AI agents to read, search, quote, and cite from your personal library of academic sources stored as markdown files using your BibTeX keys.

These are CLI tools created for use by AI coding/analysis agents (codex, Claude Code, rovodev, etc.) focused on philosophical analysis: reading, searching, quoting, and citing.


## Goals
- Keep mental model simple: discover → read → quote/cite.
- Reduce friction in common scenarios
- Include human-only extensions which are invisible to AI agents (not mentioned in `--help` and documented in `agent-tool-instructions-FOR-HUMANS-ONLY.md`).


## Scenarios
- An agent is given a draft which contains plain text references like "Steward, H. (2009). Animal Agency. Inquiry, 52(3), 217–231.". The agent is asked to create a list of the corresponding BibTeX keys in my library.

- an agent is given a draft and a list of BibTeX keys. For each BibTeX key, the agent must read the corresponding source and identify any points where the draft misrepresents the source.

- an agent is reviewing a draft which contains BibTeX citations. The agent’s task is to check that the draft provides an accurate, insightful and fair characterisation of the sources it cites.

- an agent is given a topic, or a draft, and is asked to find potentially relevant academic sources in my library.


## Install and Requirements
- Ensure `jq` is installed (required for `find-bib`)
- Set `$BIB_FILE` to the location of your BibTeX file and `$PAPERS_DIR` to the folder containing your markdown sources (or use defaults if you are configuring a dedicated host) machine).
- Run `./install.sh` to copy executable tools into a user bin.

### Requirements
- `$BIB_FILE` points to your BibTeX file
- `$PAPERS_DIR` points to your directory .md files, where each file basename includes the BibTeX key with any colons removed.

If, like me, you have old `.md` files and are using a tool to map them to BibTeX keys which you are gradually improving, you can also have a file called `bibtex-index.jsonl` in `$PAPERS_DIR` with this format:

```json
{"key": "liu:2022_facial", "filename": "Liu et al 2022 - Facial expressions elicit multiplexed perceptions of emotion categories and liu2022_facial.md"}
```


## Usage
Copy `agent-tool-instructions.md` to your agent’s working directory. Tell the agent to read this file and use the tools when performing your tasks.


## DIY
These tools work well for me but you might not want these exact tools yourself. Copy just the `specs/` folder and `agent-tool-instructions.md`, modify the spec for each tool to suit your needs, then ask codex or whoever to implement.


## How This Came About
I used to copy sources that I wanted an agent to read for each task into a directory. This was quite slow, and it became harder and harder to ensure that the agent could only see the sources I wanted it to see.

I first thought about using MCP, but this is simpler. I was also inspired by 
[Cameron’s My Take on the MCP vs CLI Debate](https://www.async-let.com/posts/my-take-on-the-mcp-verses-cli-debate/) and some of the notes that he cites.


## `agent-tool-instructions.md`
This file is for the agent. It instructs the agent on how to use each tool.


## Testing
- Run individual test scripts in `tests/` directly:
  - `bash tests/cat-sources.test.sh`
  - `bash tests/fd-sources-cat.e2e.test.sh`
  - etc
- Tests rely on local scripts in this directory being executable (no `./` prefix is required if installed on PATH, but tests call them via `./`).
- The `find-bib` tests use a small CSL‑JSON fixture at `tests/fixtures/phd_biblio.json` and a small BibTeX fixture at `tests/fixtures/sample.bib` for `--cat` integration with `cite2bib`.


## Humans
I initially intended these tools to be for agents only but ended up using them myself.
Human-friendly extensions are documented in `agent-tool-instructions-FOR-HUMANS-ONLY.md`.
To see human-specific help, run any tool with `--human` (instead of `--help`).
Never let your agents know about the human-specific extensions.


## Contributing Tools
- For each tool, there must be an accurate, up-to-date spec in `specs/`
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
  - Prefer minimal CLI surface: long flags only, avoid short aliases and decorative output (e.g., no headers/line numbers). Keep defaults strong over configurability.
  - Encourage list → then read one workflows in `--help` examples. Avoid examples that suggest streaming many files at once unless necessary for a use case.
- Documentation hook
  - After adding a tool, add a short entry to `instructions.md` (agent-facing). Avoid duplicating `--help` text.
- Help text is externalized
  - Keep help text in `help-texts/` named after the tool (e.g., `cite2md.help.txt`).
  - Load help text from file in the tool (e.g., `cat help-texts/cite2md.help.txt`).
- Testing
  - Provide a minimal smoke test or example commands. Add test scripts under `tests/`.
