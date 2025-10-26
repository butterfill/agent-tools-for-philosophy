# Agent Tools for Philosophy

**Command-line tools that let AI agents search, read, and cite sources from your personal library.**

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE.md)
![Platform](https://img.shields.io/badge/platform-macOS%20%7C%20Linux-lightgrey.svg)

Created for my own philosophical research.

---

## Table of Contents
- [Who This Is For](#who-this-is-for)
- [What's Included](#whats-included)
- [Quick Start](#quick-start)
- [Requirements](#requirements)
- [Installation](#installation)
- [Usage](#usage)
- [Example Workflows](#example-workflows)
- [Status](#status)
- [Limitations](#limitations)
- [Customization](#customization)
- [For Human Users](#for-human-users)
- [Testing](#testing)
- [Contributing](#contributing)
- [Background](#background)
- [Contact](#contact)

---

## Who This Is For

This toolkit is designed for researchers who:
- Have a collection of academic papers as **markdown files**
- Maintain a **BibTeX bibliography** for their research
- Want to use **AI agents** to help with fact-checking, citation verification, and research tasks
- Need programmatic access to their personal research library

---

## What's Included

Eight command-line tools for working with your research library:

| Tool | Purpose |
|------|---------|
| **`cite2md`** | Convert a BibTeX key or citation to a markdown file path (or print contents) |
| **`cite2bib`** | Get the BibTeX entry for a citation or key |
| **`cite2pdf`** | Locate the PDF file for a citation or key |
| **`draft2keys`** | Extract all BibTeX keys from a draft document |
| **`find-bib`** | Search your bibliography by author, title, year, or abstract |
| **`path2key`** | Extract the BibTeX key from a filename or path |
| **`rg-sources`** | Search full text of all papers using ripgrep |
| **`fd-sources`** | Find papers by filename pattern |
| **`cat-sources`** | Print contents of source files from filenames or paths |

All tools follow a consistent pattern: list → then read one. This helps manage context limits when working with AI agents.

---

## Quick Start

### 1. Installation

```bash
# Clone the repository
git clone https://github.com/yourusername/agent-tools-for-philosophy.git
cd agent-tools-for-philosophy

# Run install script (copies tools to your PATH and runs tests)
./install.sh
```

### 2. Set Up Environment Variables

Before using the tools, set these environment variables (add to your `.bashrc`, `.zshrc`, etc.):

```bash
# Path to your BibTeX file
export BIB_FILE="$HOME/documents/research/my-bibliography.bib"

# Path to your directory of markdown papers
# Each file should have the BibTeX key (without colons) in its filename
export PAPERS_DIR="$HOME/papers"
```

### 3. Instruct Your Agent
```bash
# Copy instructions to your working directory
cp ~/path/to/agent-tools/agent-tool-instructions.md .

# start your agent
codex # or claude, opencode, ...

# in the agent: 
"We are aiming to achieve X. Please review agent-tool-instructions.md \
to understand the available tools. Your task is to ..."

```

### 4. (Optional) Try a Simple Command Yourself

```bash
# Search for papers by an author
find-bib --author "Steward"

# Get the markdown file for a specific paper
cite2md vesper:2012_jumping

# Read the full text
cite2md --cat vesper:2012_jumping | head -20
```

---

## Requirements

### Platforms
- macOS or Linux

### Required Dependencies
- **`jq`** — JSON processing (required for `find-bib`, `cite2bib`, `cite2md`)
- **`fd`** — Fast file finding; alias to `fd` if it’s `fdfind` on your platform ([installation guide](https://github.com/sharkdp/fd#installation))
- **`rg`** (ripgrep) — Fast text search ([installation guide](https://github.com/BurntSushi/ripgrep#installation))

Install on macOS:
```bash
brew install jq fd ripgrep
```

Install on Ubuntu/Debian:
```bash
sudo apt install jq fd-find ripgrep
ln -s $(command -v fdfind) ~/.local/bin/fd
```

### Optional Dependencies
- **`gawk`** on macOS (`brew install gawk`) — will be used if available for better performance

### Environment Variables
- **`$BIB_FILE`** — Must point to your BibTeX file
- **`$PAPERS_DIR`** — Must point to your directory of `.md` files
  - Each markdown filename should include the BibTeX key with colons removed
  - Example: `vesper2012_jumping.md` for key `vesper:2012_jumping`

### Optional: BibTeX Index File

If you do not want BibTeX keys in `.md` file names, you can create a `bibtex-index.jsonl` file in your `$PAPERS_DIR`:

```json
{"key": "liu:2022_facial", "filename": "Liu et al 2022 - Facial expressions elicit multiplexed perceptions of emotion categories.md"}
```

---

## Installation

Run the install script:

```bash
./install.sh
```

This will:
1. Copy all executable tools to a directory on your PATH (tries `~/syncthing/bin`, `~/.local/bin`, or `~/bin`)
2. Copy help text files to `help-text/` subdirectory
3. Run the test suite to verify everything works

If the installer reports that the target directory is not on your PATH, add it to your shell profile:

```bash
# For bash
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc

# For zsh
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc
```

---

## Usage

### For AI Agents

Copy `agent-tool-instructions.md` to your agent's working directory:

```bash
cp /path/to/agent-tools-for-philosophy/agent-tool-instructions.md .
```

Then instruct your AI agent (via your agent framework) to read this file and use the tools. The file contains concise, agent-friendly documentation for each tool.

**Example with an AI agent CLI** (e.g., `aider`, `codex`, or similar):

```bash
# Copy instructions to your working directory
cp ~/path/to/agent-tools/agent-tool-instructions.md .

# Start your AI agent and give it instructions
# (this attempts everything at once; unless it's a very small draft, better to break into steps)
your-agent-cli "Please read agent-tool-instructions.md and help me fact-check draft.md 
against the sources it cites. For each citation, verify the quotes and claims are accurate."
```

### For Humans

For extended human-friendly features, use `--human` instead of `--help`:

```bash
cite2md --human
```

Human-specific extensions (like opening files in VS Code, revealing in Finder) are documented in `agent-tool-instructions-FOR-HUMANS-ONLY.md` but are **hidden from agents** to keep their interface minimal.

---

## Example Workflows

### Workflow 1: Extract and Verify Citations from a Draft

**Scenario:** You've written a draft that cites several sources. You want to verify each citation is accurate.

```bash
# Copy agent instructions to your working directory
cp ~/agent-tools/agent-tool-instructions.md .

# Ask your AI agent to extract citation keys
your-agent "Please identify the most important sources cited in draft.md. 
For each source, find its BibTeX key using the tools in agent-tool-instructions.md. 
Create a file called found-keys.txt with the keys, one per line."

# Review the keys file
cat found-keys.txt

# Ask the agent to fact-check each source
your-agent "For each key in found-keys.txt, read the corresponding source and check 
whether draft.md represents it accurately. Create a report in checking/ directory."
```

### Workflow 2: Verify a Specific Citation

**Scenario:** You want to check if your draft accurately represents a specific source.

```bash
# Copy agent instructions
cp ~/agent-tools/agent-tool-instructions.md .

# Ask agent to verify
your-agent "Review agent-tool-instructions.md to understand the available tools. 
Check draft.md against the source with key mylopoulos:2019_intentions. 
Assess whether draft.md represents the source accurately, fairly, and charitably. 
If there are mistakes, they are of first importance. If there is relevant material 
in the source that draft.md overlooks, note that too.

Create a file checking/mylopoulos2019_intentions.md with headings for each issue.
Under each heading include:
1. A concise statement of the issue
2. Verbatim quotes from draft.md (in \"double quotes\")
3. Verbatim quotes from the source (in \"double quotes\")

Use double quotes only for quotations."
```

### Workflow 3: Find Related Literature

**Scenario:** The agent is researching a topic and wants to see what's in your library.

```bash
# Search by author
find-bib --author "Steward" --author "Velleman"

# Search abstracts for key terms
find-bib --abstract "motor representation"

# Full-text search across all papers
rg-sources "bayesian prior" -i -C 2

# Find papers by filename pattern
fd-sources "intention" | head -5
```


---

## Status

**Status: Experimental**

(I'm making the repo public mainly to share the approach rather than the code.)

---

## Limitations

### Path Safety and AI Agent Use

These tools are **not designed to provide security isolation**. While some tools reject absolute paths and parent-directory traversal in their inputs (`cat-sources`, `fd-sources`, `rg-sources`), others work with or return absolute paths (`cite2md`, `cite2pdf`, `path2key`). The tools scope searches to `$PAPERS_DIR` for convenience, not security.

**I use these tools in a disposable VPS where this is fine for my workflow.** They should not be used by an AI agent in an environment where giving the agent access to arbitrary file paths could be a problem. These tools are unsuitable if you're running an agent with access to sensitive files or systems (but see [Customization](#customization) below).

---

## Customization

These tools work well for me, but you may want to adapt them for your own workflow.
Copy just the `specs/` folder and `agent-tool-instructions.md`, modify the specifications to suit your needs, then ask an agent to implement your own versions.

---

## For Human Users
I initially intended these tools to be for agents only but ended up using them myself.

**Human-specific features** (hidden from agents):
- Open files in VS Code: `cite2md --vs <key>`
- Reveal in Finder: `cite2md --reveal <key>`
- ...

See `agent-tool-instructions-FOR-HUMANS-ONLY.md` for full details.

Run any tool with `--human` to see human-friendly help:

```bash
cite2md --human
```

**Why hide these from agents?**  
To keep the agent interface minimal and focused. Agents don't need editor integrations or GUI operations.

---

## Testing

### Run All Tests

```bash
./run-tests.sh
```

### Run Individual Tests

```bash
# Unit tests
bash tests/cite2bib.test.sh
bash tests/draft2keys.test.sh

# End-to-end tests
bash tests/fd-sources-cat.e2e.test.sh
bash tests/rg-sources.e2e.test.sh
```

### Test Notes
- Tests call scripts via `./` prefix (assuming current directory)
- Some tests use fixtures in `tests/fixtures/`
- The `find-bib` tests use `tests/fixtures/phd_biblio.json` (CSL-JSON)
- The `cite2bib` tests use `tests/fixtures/sample.bib`

---

## Contributing

### Adding New Tools

If you want to contribute a new tool:

1. **Create a spec** in `specs/` describing the tool's purpose, inputs, outputs, and behavior
2. Pick a clear, short command name (hyphenated if necessary). Extensions should not be used.
2. **Implement the tool** as an executable script in the root directory
3. **Follow the baseline pattern:**
   - Start with `#!/usr/bin/env bash` and `set -euo pipefail`
   - Provide `--help` flag with concise usage
   - Return consistent exit codes: 0 (success), 1 (not found), 2 (usage/config error)
   - Use environment variables for configuration (e.g., `PAPERS_DIR`)
4. **Externalize help text** in `help-text/<tool-name>-help.txt` and `help-text/<tool-name>-human.txt`
5. **Write tests** in `tests/<tool-name>.test.sh`
6. **Update documentation:**
   - Add entry to `agent-tool-instructions.md`
   - Mention in this README if it's a major addition

### Code Style Guidelines

- **Prefer standard Unix tools:** `fd`, `rg`, `jq`, `yq`, `ast-grep`
- **Output discipline**
  - Keep stdout for the tool’s primary data. Send diagnostics to stderr.
  - Avoid extra wrapper noise; let underlying tools (e.g., `rg`) control formatting.
- **Fail fast:** Check dependencies and show clear error messages
- **Minimal CLI surface:** Long flags only, strong defaults over configurability, avoid short aliases and decorative output (e.g., no headers/line numbers).
- **List → read pattern:** Encourage workflows that list first, then read one item at a time
- **Environment and scope**
  - Prefer environment variables for configurable roots (e.g., `PAPERS_DIR` with a safe default).
  - Check environment variables already in use before requiring any new ones.
  - If a tool must access outside the repo, scope carefully and validate inputs (e.g., reject absolute `paths`).

See the "Contributing Tools" section in the current README for full guidelines.

---

## Background

### Goals

- **Keep the mental model simple:** discover → read → quote/cite
- **Reduce friction** in common research scenarios
- **Include human-only extensions** that are invisible to AI agents (not in `--help`, documented separately)


### How This Came About
I used to copy sources that I wanted an agent to read for each task into a directory. This was quite slow, and it became harder and harder to ensure that the agent could only see the sources I wanted it to see.

I first thought about using MCP, but this is simpler. 
I was inspired by 
Armin Ronacher’s [Tools: Code Is All You Need](https://lucumr.pocoo.org/2025/7/3/tools/)
and Cameron’s 
[My Take on the MCP vs CLI Debate](https://www.async-let.com/posts/my-take-on-the-mcp-verses-cli-debate/)
as well as some things Simon Willison wrote. Thank you!

---

## Contact

[butterfill.com](https://butterfill.com)

---

## License

MIT License. Attribution appreciated.

See [LICENSE.md](LICENSE.md) for full text.
