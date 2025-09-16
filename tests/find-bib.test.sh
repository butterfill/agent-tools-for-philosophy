#!/usr/bin/env bash
set -euo pipefail

# Simple tests for new CSL-JSON based find-bib

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)
cd "$REPO_ROOT"

TOOL="./find-bib"
FIXTURE_JSON="tests/fixtures/phd_biblio.json"

# Ensure local tools are discoverable (cite2bib) for --cat integration
export PATH="$REPO_ROOT:$PATH"

pass=0
fail=0

require() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "SKIP: missing dependency: $cmd" >&2
    exit 2
  fi
}

require jq
require rg

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

run_output() {
  bash -lc "$*"
}

has_line_matching() {
  local pattern="$1"; shift
  local out
  if ! out=$(run_output "$@" 2>/dev/null); then
    return 1
  fi
  rg -q "$pattern" <<< "$out"
}

has_n_lines() {
  local n="$1"; shift
  local out
  if ! out=$(run_output "$@" 2>/dev/null); then
    return 1
  fi
  test "$(printf '%s\n' "$out" | sed '/^$/d' | wc -l | tr -d ' ')" -eq "$n"
}

# 1) Field filters: Steward 2009 Animal Agency
it "finds Steward 2009 Animal Agency by field filters" \
  has_line_matching '^steward:2009_animal$' \
  BIB_JSON="$FIXTURE_JSON" "$TOOL" --author steward --year 2009 --title animal

# 2) Abstract/topic search: motor (find smith 2021)
it "finds Smith 2021 by abstract contains 'motor'" \
  has_line_matching '^smith:2021_joint$' \
  BIB_JSON="$FIXTURE_JSON" "$TOOL" --abstract motor

# 3) limit parameter
it "respects --limit for author with multiple entries (Steward)" \
  has_n_lines 1 \
  BIB_JSON="$FIXTURE_JSON" "$TOOL" --author steward --limit 1

# 4) JSON output
it "outputs compact JSON with --json" \
  has_line_matching '"id"\s*:\s*"agrillo:2017_numerical"' \
  BIB_JSON="$FIXTURE_JSON" "$TOOL" --author agrillo --json

# 5) cat output via cite2bib (using sample.bib fixture)
if command -v cite2bib >/dev/null 2>&1; then
  it "emits BibTeX via --cat for smith:2021_joint" \
    has_line_matching '^@\w+\{smith:2021_joint,' \
    BIB_FILE="tests/fixtures/sample.bib" BIB_JSON="$FIXTURE_JSON" "$TOOL" --author smith --cat
else
  echo "SKIP: cite2bib not found; skipping --cat test" >&2
fi

echo "RESULT: $pass passed, $fail failed"
test "$fail" -eq 0
