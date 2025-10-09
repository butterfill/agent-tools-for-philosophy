# Human Help Flag — Partition Agent vs Human Guidance

We need a consistent way to expose richer, human-only guidance without surfacing it to AI agents. Every CLI tool in this repository will grow a `--human` flag that emits expanded help text, while the existing `--help` output is trimmed to agent-safe essentials.

## Goals
- Keep the default `--help` terse, agent-friendly, and free of human-only hints.
- Provide humans with fuller context (workflows, environment variables, dependencies, hidden flags) via `--human`.
- Make the experience consistent across all tools so users know where to look for each class of information.

## Scope
- Applies to every executable shipped in this repo (e.g., `cite2md`, `cite2bib`, `draft2keys`, `path2key`, `rg-sources`, `fd-sources`, `cat-sources`, `find-bib`, etc.).
- Covers documentation, CLI flag parsing, and tests that assert on help output.

## Terminology
- **Agent-visible**: Content safe to expose via `--help` (no implementation details, internal paths, or human-only affordances).
- **Human-only**: Additional instructions useful for humans (e.g., environment configuration, troubleshooting steps, hidden productivity flags).

## Requirements

### `--help`
- Retain short description, canonical usage line(s), and agent-safe flags.
- DO NOT mention the existence of `--human` so agents do not accidentally discover it.
- Exclude sections currently labeled as implementation details, resolution strategies, environment variables, dependency lists, or hidden features.
- Continue to exit with status 0.

### `--human`
- New flag available on every tool.
- Emits the same core information as `--help`, followed by human-only sections.
- Must include (when applicable):
  - Environment variables and configuration files.
  - Resolution/lookup strategies or implementation hints.
  - Dependency/tooling requirements.
  - Human-only flags (`--vs`, `--vsi`, `--reveal`, etc.).
  - Recommended workflows, troubleshooting guidance, or productivity tips.
- If multiple human-only sections exist, order them logically (e.g., Usage → Environment → Resolution → Dependencies → Human-only shortcuts).
- Should exit with status 0 and suppress normal tool execution (i.e., no additional positional arguments allowed when `--human` is present).

### Flag Interactions
- `--human` is mutually exclusive with execution flags or positional arguments. Detect and fail with exit code 2 when combined with other inputs.
- When both `--help` and `--human` are passed, prefer `--human` (document this in spec and enforce consistently).

### Hidden Features
- Features already reserved for humans (like the `cite2md --vs` action) move out of `--help` output and live under `--human`.
- Any future human-only affordances must be documented under `--human` instead of `--help`.

### Tests & Tooling
- Update existing tests that snapshop or assert on `--help` output so they reflect the trimmed content.
- Add new coverage where helpful to ensure:
  - `--help` omits human-only sections.
  - `--human` includes the expanded information.
  - Conflicting usage (e.g., `tool --human key`) returns the documented usage error.

## Rollout Steps (per tool)
1. Refactor help text into shared pieces (core vs human-only).
2. Add `--human` flag handling with the mutual exclusion rules.
3. Update documentation/specs/tests for each tool accordingly.
