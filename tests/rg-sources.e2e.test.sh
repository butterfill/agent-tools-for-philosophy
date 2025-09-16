#!/usr/bin/env bash
set -euo pipefail

# E2E tests for rg-sources using real $HOME/papers

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)
cd "$REPO_ROOT"

TOOL="$REPO_ROOT/rg-sources"

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

if [[ ! -d "$HOME/papers" ]]; then
  echo "SKIP: PAPERS_DIR not found at $HOME/papers" >&2
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

run_ok_and_matches() {
  local pattern="$1"; shift
  local out
  if ! out=$(PAPERS_DIR="$HOME/papers" "$TOOL" -n "$@" 2>/dev/null); then
    return 1
  fi
  rg -q "$pattern" <<< "$out"
}

it "finds a known phrase in vesper2012_jumping via default Markdown types" \
  run_ok_and_matches 'vesper2012_jumping\.md:' "Are You Ready to Jump\?"

abs_path_rejected() {
  local rc=0
  set +e
  PAPERS_DIR="$HOME/papers" "$TOOL" -- foo "/etc" >/dev/null 2>err.txt
  rc=$?
  set -e
  rg -q 'absolute paths not allowed' err.txt && test $rc -eq 2
}

it "rejects absolute paths with an error" abs_path_rejected

echo "RESULT: $pass passed, $fail failed"
[[ "$fail" -eq 0 ]]
