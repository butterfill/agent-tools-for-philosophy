# run-tests — Unified Test Harness and Reporting

Defines how repository shell test suites are executed, how individual tests report results, and how summaries are presented so both humans and AI coding agents can quickly understand the state of the suite.

## Scope & Artifacts
- `run-tests.sh` — entry point for running suites; orchestrates summaries.
- `tests/lib/test_helpers.sh` — shared helper library for suite authors.
- `tests/*.sh` — suite files that source the helper library and contain test cases.

## Goals
- Humans can run `./run-tests.sh` and immediately see whether anything failed, with a compact failure recap that avoids scrolling through each passing assertion.
- AI coding agents (and humans) can run an individual suite (`bash tests/foo.test.sh`) or a subset (`./run-tests.sh tests/foo.test.sh tests/bar.test.sh`) and get deterministic, machine-friendly output and exit codes.
- Output remains plain ASCII so it is easy to capture, diff, or parse.

## Execution Model
1. Suites source `tests/lib/test_helpers.sh` to register themselves via `test_suite "$0"`.
2. Each test case is declared via `it "description" command ...`.
3. Helpers track per-suite pass/fail/skip counts and accumulate failure diagnostics for later replay.
4. Suites end with `complete_suite` which prints a per-suite summary (`SUITE tests/foo.test.sh: 5 passed, 1 failed, 0 skipped`) and exits non-zero if any failures occurred.
5. `run-tests.sh` iterates over requested suites (default: all `tests/*.sh`), executes each with `bash`, captures outcome, and records the suite-level result.

## Selective Execution
- `./run-tests.sh` — run every suite discovered under `tests/`.
- `./run-tests.sh tests/find-bib.test.sh` — run explicit suite paths in order given.
- `./run-tests.sh --match "find-bib"` — run suites whose basename matches the substring or regex supplied.
- `./run-tests.sh --list` — print suite paths without executing (helps scripting/auto-complete).
- Suites remain directly executable: `bash tests/find-bib.test.sh` uses the same helper output and exits with the same code that the harness relies on.

## Output Format
### During Suite Execution
- `run-tests.sh` prints `RUN tests/foo.test.sh` before invoking each suite.
- Inside the suite, each test line is emitted as `  ok description` or `  not ok description`.
- On failure, the helper collects additional context (stdout/stderr snippets provided by the test case) and prints them directly beneath the `not ok` line, indented two spaces for readability.
- Skipped tests log `  skip description (reason)` and increment the skip counter.

### After Each Suite
- `complete_suite` prints one line: `SUITE tests/foo.test.sh: 12 passed, 1 failed, 0 skipped`.
- If there were failures, the helper prints the buffered diagnostics immediately after the suite summary, scoped to that suite.
- The suite exits with:
  - `0` if all tests passed.
  - `1` if at least one `it` failed.
  - `2` if the suite skipped entirely due to missing prerequisites (`skip_suite "reason"` helper).

### Final Harness Summary
- After all suites run, `run-tests.sh` prints:
  - `TOTAL: <suites_run> suites, <passed> passed, <failed> failed, <skipped> skipped, duration <elapsed>s`
  - If there are failures: a concise recap block
    ```
    FAILURES:
      tests/find-bib.test.sh
        not ok finds Smith 2021 by abstract contains 'motor'
      tests/path2key.test.sh
        not ok resolves via index fallback when heuristic doesn't match
    ```
- `run-tests.sh` exits `0` when every suite succeeds or is skipped, `1` if any suite fails.

## Diagnostics Convention
- Test callbacks return success/failure; when a callback fails it should print its own diagnostic details (command run, expected vs actual) to stdout/stderr. The helper captures the block via command substitution so it can replay the output under the failure heading.
- Helpers provide `with_tmpdir`, `capture`, or similar utilities so fixtures can record command output without verbose plumbing in each suite.

## Machine-Friendly Guarantees
- Output lines start with consistent tokens (`RUN`, `SUITE`, `TOTAL`, `FAILURES`, `  ok`, `  not ok`, `  skip`) enabling trivial parsing.
- All control messages originate from helpers; suites must avoid ad-hoc printf logging outside of explicit diagnostics to keep noise low.
- Exit codes follow the documented contract, allowing agents to gate follow-up work on success/failure without reading logs.

## Human Experience
- No scrolling required to find broken tests: failures are listed twice (inline within the suite and in the final recap).
- Passing tests collapse to a single `  ok` line, avoiding repetitive `PASS`/`RESULT` banners.
- Skips are visible but quiet; skipped entire suites produce a single `SUITE … skipped` note.
