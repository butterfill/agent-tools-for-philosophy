#!/usr/bin/env bash
set -euo pipefail

# E2E tests for cite2md using real $PAPERS_DIR

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)
cd "$REPO_ROOT"

TOOL="$REPO_ROOT/cite2md"
PAPERS_ROOT="${PAPERS_DIR:-$HOME/papers}"

pass=0
fail=0

require() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "SKIP: missing dependency: $cmd" >&2
    exit 2
  fi
}

require fd
require rg
require jq

if [[ ! -d "$PAPERS_ROOT" ]]; then
  echo "SKIP: PAPERS_DIR not found at $PAPERS_ROOT" >&2
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

outputs_path_and_exists() {
  local key="$1"
  local path
  if ! path=$(PAPERS_DIR="$PAPERS_ROOT" "$TOOL" "$key" 2>/dev/null); then
    return 1
  fi
  [[ -n "$path" && -f "$path" ]]
}

# Choose a well-known key we expect to exist in this environment
KEY_WITH_COLON="vesper:2012_jumping"
KEY_NORM="vesper2012_jumping"

it "path lookup works for key with colon" \
  outputs_path_and_exists "$KEY_WITH_COLON"

it "path lookup works for normalized key (no colon)" \
  outputs_path_and_exists "$KEY_NORM"

it "latex citation form resolves and contains header when --cat" \
  has_line_matching '^# Are You Ready to Jump\?' \
  PAPERS_DIR="$PAPERS_ROOT" "$TOOL" --cat "\\citet{$KEY_WITH_COLON}"

reads_from_stdin_single() {
  local path
  if ! path=$(printf '%s\n' "$KEY_WITH_COLON" | PAPERS_DIR="$PAPERS_ROOT" "$TOOL" 2>/dev/null); then
    return 1
  fi
  [[ -n "$path" && -f "$path" ]]
}

it "reads path from stdin for a single key" reads_from_stdin_single

writes_missing_fulltext_log() {
  local missing="no:such_key_zzzz"
  rm -f missing-fulltext.txt
  set +e
  PAPERS_DIR="$PAPERS_ROOT" "$TOOL" "$missing" >/dev/null 2>err.txt
  rc=$?
  set -e
  test $rc -eq 1 && rg -q "^$missing$" missing-fulltext.txt
}

it "appends missing keys to missing-fulltext.txt in cwd" writes_missing_fulltext_log

echo "RESULT: $pass passed, $fail failed"
[[ "$fail" -eq 0 ]]
