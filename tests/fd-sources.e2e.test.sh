#!/usr/bin/env bash
set -euo pipefail

# E2E tests for fd-sources using real $PAPERS_DIR

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)
cd "$REPO_ROOT"

TOOL="$REPO_ROOT/fd-sources"
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

run_ok_and_matches() {
  local pattern="$1"; shift
  local out
  if ! out=$(PAPERS_DIR="$PAPERS_ROOT" "$TOOL" "$@" 2>/dev/null); then
    return 1
  fi
  rg -q "$pattern" <<< "$out"
}

it "finds vesper2012_jumping filename by substring" \
  run_ok_and_matches 'vesper2012_jumping\.md$' "vesper2012_jumping"

abs_path_rejected() {
  local rc=0
  set +e
  PAPERS_DIR="$PAPERS_ROOT" "$TOOL" -- "/etc" >/dev/null 2>err.txt
  rc=$?
  set -e
  rg -q 'absolute paths not allowed' err.txt && test $rc -eq 2
}

it "rejects absolute path arguments" abs_path_rejected

echo "RESULT: $pass passed, $fail failed"
[[ "$fail" -eq 0 ]]

