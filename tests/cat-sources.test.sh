#!/usr/bin/env bash
set -euo pipefail

# Tests for cat-sources (uses real $PAPERS_DIR if present)

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)
cd "$REPO_ROOT"

source "$REPO_ROOT/tests/lib/test_helpers.sh"
test_suite "$0"

TOOL="$REPO_ROOT/cat-sources"
PAPERS_ROOT="${PAPERS_DIR:-$HOME/papers}"

if [[ ! -x "$TOOL" ]]; then
  skip_suite "cat-sources tool not executable"
fi

if [[ ! -d "$PAPERS_ROOT" ]]; then
  skip_suite "PAPERS_DIR not found at $PAPERS_ROOT"
fi

require_command rg fd

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

complete_suite
