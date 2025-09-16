#!/usr/bin/env bash
set -euo pipefail

# Tests for find-bib.sh
#
# Assumptions (documented):
# - $PAPERS_DIR exists and remains stable (default: $HOME/papers)
# - rg-sources is installed and works against $PAPERS_DIR
# - $BIB_FILE exists (default: $HOME/endnote/phd_biblio.bib)
# - Tools installed on PATH or runnable via relative path from repo root

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")"/../.. && pwd)
cd "$REPO_ROOT"

TOOL="agent-tools/find-bib.sh"

pass=0
fail=0

require() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "SKIP: missing dependency: $cmd" >&2
    exit 2
  fi
}

require rg
require awk
require sed
require rg-sources

# Helper to run a test and record pass/fail
it() {
  local name="$1"; shift
  echo "TEST: $name"
  if "$@"; then
    echo "  PASS"
    pass=$((pass+1))
  else
    echo "  FAIL ($name)" >&2
    fail=$((fail+1))
  fi
}

# Runner helpers
run_output() {
  # Prints command output; returns 0 for success of command
  bash -lc "$*"
}

has_line_matching() {
  local pattern="$1"; shift
  local out
  if ! out=$(run_output "$@" 2>/dev/null); then
    return 1
  fi
  echo "$out" | rg -q "$pattern"
}

has_n_lines() {
  local n="$1"; shift
  local out
  if ! out=$(run_output "$@" 2>/dev/null); then
    return 1
  fi
  test "$(printf '%s\n' "$out" | sed '/^$/d' | wc -l | tr -d ' ')" -eq "$n"
}

# --- Tests ---

# 1) Scenario 1 — full citation via field filters
it "finds Steward 2009 Animal Agency by field filters" \
  has_line_matching '^steward:2009_animal$' \
  "$TOOL" --author steward --year 2009 --title "animal agency"

# 2) Scenario 1 — free-text citation line
it "finds key from free-text citation line" \
  has_line_matching '^steward:2009_animal$' \
  "$TOOL" 'Steward, H. (2009). Animal Agency. Inquiry, 52(3), 217–231.'

# 3) Scenario 2 — topic search in sources (joint action)
it "lists some joint action related keys from sources" \
  has_line_matching '^(knoblich:2002_mirror|pesquita:2018_predictive|sinigaglia:2022_motor|butterfill:2016_minimal|sacheli:2018_evidence)$' \
  "$TOOL" --sources "joint action" --limit 200

# 4) Intersection of sources and bib filters (Butterfill on acting together)
it "intersects sources and bib filters (Butterfill)" \
  has_line_matching '^sinigaglia:2022_motor$' \
  "$TOOL" --sources "acting together" --author butterfill --year 2022 --title motor

# 5) with-md output formatting for a known mapped key
it "outputs key and markdown path with --with-md" \
  has_line_matching '^sinigaglia\:2022_motor[[:space:]]+/.*/sinigaglia2022_motor\.md$' \
  "$TOOL" --author sinigaglia --year 2022 --title motor --with-md --limit 5

# 6) limit parameter restricts number of lines
it "respects --limit for author with many entries" \
  has_n_lines 1 \
  "$TOOL" --author steward --limit 1

echo "RESULT: $pass passed, $fail failed"
test "$fail" -eq 0

