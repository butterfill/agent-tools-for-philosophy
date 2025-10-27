#!/usr/bin/env bash
set -euo pipefail

# E2E tests for find-bib using real $HOME/endnote/phd_biblio.json and cite2bib for --cat

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)
cd "$REPO_ROOT"

source "$REPO_ROOT/tests/lib/test_helpers.sh"
test_suite "$0"

TOOL="$REPO_ROOT/find-bib"
BIB_JSON_PATH="${BIB_JSON:-$HOME/endnote/phd_biblio.json}"
BIB_JSON_PATH="${BIB_JSON:-$HOME/endnote/phd_biblio.json}"
BIB_FILE_PATH="${BIB_FILE:-$HOME/endnote/phd_biblio.bib}"

# Ensure local tools are discoverable (cite2bib) for --cat
export PATH="$REPO_ROOT:$PATH"

require_command jq rg

if [[ ! -f "$BIB_JSON_PATH" ]]; then
  skip_suite "CSL-JSON not found at $BIB_JSON_PATH"
fi

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
  BIB_JSON="$BIB_JSON_PATH" "$TOOL" --author vesper --year 2013 --title jump


# 2) --cat emits BibTeX via cite2bib when BIB_FILE provided
if command -v cite2bib >/dev/null 2>&1; then
  it "--cat prints a BibTeX entry for vesper:2012_jumping" \
    has_line_matching '^@\w+\{vesper:2012_jumping,' \
    BIB_FILE="$BIB_FILE_PATH" BIB_JSON="$BIB_JSON_PATH" "$TOOL" --author vesper --year 2013 --title jump --cat
else
  skip "--cat prints a BibTeX entry for vesper:2012_jumping" "cite2bib not on PATH"
fi

complete_suite
