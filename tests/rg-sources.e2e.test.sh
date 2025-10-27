#!/usr/bin/env bash
set -euo pipefail

# E2E tests for rg-sources using real $PAPERS_DIR

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)
cd "$REPO_ROOT"

source "$REPO_ROOT/tests/lib/test_helpers.sh"
test_suite "$0"

TOOL="$REPO_ROOT/rg-sources"
PAPERS_ROOT="${PAPERS_DIR:-$HOME/papers}"

require_command rg

if [[ ! -d "$PAPERS_ROOT" ]]; then
  skip_suite "PAPERS_DIR not found at $PAPERS_ROOT"
fi

run_ok_and_matches() {
  local pattern="$1"; shift
  local out
  if ! out=$(PAPERS_DIR="$PAPERS_ROOT" "$TOOL" -n "$@" 2>/dev/null); then
    return 1
  fi
  rg -q "$pattern" <<< "$out"
}

it "finds a known phrase in vesper2012_jumping via default Markdown types" \
  run_ok_and_matches 'vesper2012_jumping\.md:' "Are You Ready to Jump\?"

abs_path_rejected() {
  local rc=0
  set +e
  PAPERS_DIR="$PAPERS_ROOT" "$TOOL" -- foo "/etc" >/dev/null 2>err.txt
  rc=$?
  set -e
  rg -q 'absolute paths not allowed' err.txt && test $rc -eq 2
}

it "rejects absolute paths with an error" abs_path_rejected

complete_suite
