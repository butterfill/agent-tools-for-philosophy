#!/usr/bin/env bash
set -euo pipefail

# Tests for cat-sources (uses real $PAPERS_DIR if present)

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)
cd "$REPO_ROOT"

TOOL="$REPO_ROOT/cat-sources"
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

if [[ ! -x "$TOOL" ]]; then
  echo "SKIP: cat-sources tool not executable" >&2
  exit 2
fi

if [[ ! -d "$PAPERS_ROOT" ]]; then
  echo "SKIP: PAPERS_DIR not found at $PAPERS_ROOT" >&2
  exit 2
fi

require rg
require fd

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

prints_known_file() {
  local out
  if ! out=$(PAPERS_DIR="$PAPERS_ROOT" "$REPO_ROOT/fd-sources" 'vesper2012_jumping' 2>/dev/null | PAPERS_DIR="$PAPERS_ROOT" "$TOOL" 2>/dev/null); then
    return 1
  fi
  rg -q "Are You Ready to Jump\?" <<< "$out"
}

it "prints content of a known file" prints_known_file

abs_path_rejected() {
  local rc=0
  set +e
  PAPERS_DIR="$PAPERS_ROOT" "$TOOL" "/etc/passwd" >/dev/null 2>err.txt
  rc=$?
  set -e
  rg -q 'absolute paths not allowed' err.txt && test $rc -eq 2
}

it "rejects absolute paths with an error" abs_path_rejected

echo "RESULT: $pass passed, $fail failed"
[[ "$fail" -eq 0 ]]
