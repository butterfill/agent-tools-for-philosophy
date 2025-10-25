# Agent Tools for Philosophy

CLI tools to enable AI agents to search, read, quote, and cite from your personal library of academic sources stored as markdown files, using your BibTeX keys.

Focused on assisting philosophical research: checking for accuracy, searching, and quoting.



## Quickstart Example 1
```bash
# Install tools and run tests
./install.sh
```
The, in a folder containing a draft `draft.md` you are thinking about:

```bash
cp ~/LOCAL_PATH_TO_THIS_REPO/agent-tool-instructions.md .

codex exec "Please identify the most important sources cited in `draft.md`. For each source cited, attempt to find its BibTeX key in my library. Create a file, `found-keys.txt`, which contains a list of the BibTeX keys you found, one per line. The tools you should use to achieve this are described in `agent-tool-instructions.md`."
```

## Quickstart Example 2
```bash
# setup as in example 1

codex exec "We are checking draft.md against a source it cites. Please review agent-tool-instructions.md to understand the available tools. Your task is to check draft.md against the source with key `mylopoulos:2019_intentions` : the aim is to understand whether draft.md represents each the source accurately, fairly and charitably. If there is a mistake in draft.md, that is of the first importance. If there is material in the source which draft.md does not consider, but which would substantially change the argument of the ms were it considered, that is of the second importance. (Note that draft.md does not have to provide a comprehensive account of this source. Nor are we concerned with minor editorial issues like publication year or page numbers.) \
\
Please create a file `checking/[BibTeX-key-without-the-colon].md` which
contains a series of headings. Each heading should contain three points: (1) a consise statement of an issue; (2) one
or more verbatim quotes from draft.md concerning the issue; and (3) one or more verbatim quotes from the source. Put all
quotes in \"double quotes\" and do not use the double quote mark for any other purpose."
```



## Goals
- Keep mental model simple: discover → read → quote/cite.
- Reduce friction in common scenarios
- Include human-only extensions which are invisible to AI agents (not mentioned in `--help` and documented in `agent-tool-instructions-FOR-HUMANS-ONLY.md`).


## Scenarios
- An agent is given a draft which contains plain text references like "Steward, H. (2009). Animal Agency. Inquiry, 52(3), 217–231.". The agent is asked to create a list of the corresponding BibTeX keys in my library.

- an agent is given a draft and a list of BibTeX keys. For each BibTeX key, the agent must read the corresponding source and identify any points where the draft misrepresents the source.

- an agent is reviewing a draft which contains BibTeX citations. The agent’s task is to check that the draft provides an accurate, insightful and fair characterisation of the sources it cites.

- an agent is given a topic, or a draft, and is asked to find potentially relevant academic sources in my library.


## The Tools
Please see [`agent-tool-instructions.md`](agent-tool-instructions.md) for a list of the tools and their usage.


## Requirements
- platforms: macOS, Linux
- Ensure `jq` is installed (required for `find-bib`)
- `$BIB_FILE` points to your BibTeX file
- `$PAPERS_DIR` points to your directory .md files, where each file basename includes the BibTeX key with any colons removed.
- *optional* gawk on macOS (`brew install gawk`), will be used if available.

[optional] If, like me, you have old `.md` files and are using a tool to map them to BibTeX keys which you are gradually improving, you can also have a file called `bibtex-index.jsonl` in `$PAPERS_DIR` with this format:

```json
{"key": "liu:2022_facial", "filename": "Liu et al 2022 - Facial expressions elicit multiplexed perceptions of emotion categories and liu2022_facial.md"}
```


## Install
- Run `./install.sh` to copy executable tools into a user bin.


## Usage
Copy `agent-tool-instructions.md` to your agent’s working directory. Tell the agent to read this file and use the tools when performing your tasks.


## Status
Status: experimental.

## Customization
These tools work well for me but you might not want these exact tools yourself. Copy just the `specs/` folder and `agent-tool-instructions.md`, modify the spec for each tool to suit your needs, then ask codex or whoever to implement.

(I'm making the repo public mainly because I want to share the approach rather than the code.)


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


## Contact

[butterfill.com](https://butterfill.com)

