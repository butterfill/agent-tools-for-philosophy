#!/usr/bin/env bash
set -euo pipefail

# E2E tests for find-bib using real $HOME/endnote/phd_biblio.json and cite2bib for --cat

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)
cd "$REPO_ROOT"

TOOL="$REPO_ROOT/find-bib"

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

if [[ ! -f "$HOME/endnote/phd_biblio.json" ]]; then
  echo "SKIP: CSL-JSON not found at $HOME/endnote/phd_biblio.json" >&2
  exit 2
fi

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

# 1) Field filters for Vesper 2012 jumping
it "finds vesper:2012_jumping by author/year/title filters" \
  has_line_matching '^vesper:2012_jumping$' \
  BIB_JSON="$HOME/endnote/phd_biblio.json" "$TOOL" --author vesper --year 2013 --title jump

# 2) JSON output returns id field for vesper:2012_jumping
it "--json outputs entry with id vesper:2012_jumping" \
  has_line_matching '"id"\s*:\s*"vesper:2012_jumping"' \
  BIB_JSON="$HOME/endnote/phd_biblio.json" "$TOOL" --author vesper --year 2013 --json

# 3) Limit parameter with a prolific author
it "--limit 1 limits to a single result for Steward" \
  has_n_lines 1 \
  BIB_JSON="$HOME/endnote/phd_biblio.json" "$TOOL" --author steward --limit 1

# 4) --cat emits BibTeX via cite2bib.sh when BIB_FILE provided
if command -v cite2bib.sh >/dev/null 2>&1; then
  it "--cat prints a BibTeX entry for vesper:2012_jumping" \
    has_line_matching '^@\w+\{vesper:2012_jumping,' \
    BIB_FILE="$HOME/endnote/phd_biblio.bib" BIB_JSON="$HOME/endnote/phd_biblio.json" "$TOOL" --author vesper --year 2013 --title jump --cat --limit 1
else
  echo "SKIP: cite2bib.sh not on PATH; skipping --cat e2e" >&2
fi

echo "RESULT: $pass passed, $fail failed"
[[ "$fail" -eq 0 ]]
