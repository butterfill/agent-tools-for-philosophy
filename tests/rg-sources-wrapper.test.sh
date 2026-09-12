#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)
cd "$REPO_ROOT"

source "$REPO_ROOT/tests/lib/test_helpers.sh"
test_suite "$0"

TOOL="$REPO_ROOT/rg-sources"

require_command rg

setup_sources() {
  local dir="$1"
  printf '%s\n' "This paper discusses joint action and planning." > "$dir/butterfill:2019_goals.md"
  printf '%s\n' "This paper concerns visual attention." > "$dir/other:2020_attention.md"
  printf '%s\n' "Not searched by default." > "$dir/notes.txt"
}

searches_files_with_closed_stdin() {
  with_tmpdir _searches_files_with_closed_stdin
}

_searches_files_with_closed_stdin() {
  local papers_dir="$1"
  setup_sources "$papers_dir"
  local out
  out=$(PAPERS_DIR="$papers_dir" "$TOOL" -l -i "joint action" </dev/null)
  [[ "$out" == "butterfill:2019_goals.md" ]]
}

reads_pattern_file_from_stdin() {
  with_tmpdir _reads_pattern_file_from_stdin
}

_reads_pattern_file_from_stdin() {
  local papers_dir="$1"
  setup_sources "$papers_dir"
  local out
  out=$(printf '%s\n' "visual attention" | PAPERS_DIR="$papers_dir" "$TOOL" -l -f -)
  [[ "$out" == "other:2020_attention.md" ]]
}

it "searches the papers directory when stdin is non-interactive" searches_files_with_closed_stdin
it "preserves -f - pattern input from stdin" reads_pattern_file_from_stdin

complete_suite
