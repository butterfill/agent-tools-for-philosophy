#!/usr/bin/env bash
set -euo pipefail

# E2E tests for fd-sources --cat using real $PAPERS_DIR

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)
cd "$REPO_ROOT"

source "$REPO_ROOT/tests/lib/test_helpers.sh"
test_suite "$0"

TOOL="$REPO_ROOT/fd-sources"
PAPERS_ROOT="${PAPERS_DIR:-$HOME/papers}"

require_command fd

if [[ ! -d "$PAPERS_ROOT" ]]; then
  skip_suite "PAPERS_DIR not found at $PAPERS_ROOT"
fi

run_ok_and_matches() {
  local pattern="$1"; shift
  local out
  if ! out=$(PAPERS_DIR="$PAPERS_ROOT" "$TOOL" "$@" 2>/dev/null | "$REPO_ROOT/cat-sources" 2>/dev/null); then
    return 1
  fi
  rg -q "$pattern" <<< "$out"
}

it "prints content via pipe to cat-sources for known filename" \
  run_ok_and_matches "Are You Ready to Jump\?" "vesper2012_jumping"

complete_suite
