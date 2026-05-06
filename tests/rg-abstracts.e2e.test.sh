#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)
cd "$REPO_ROOT"

source "$REPO_ROOT/tests/lib/test_helpers.sh"
test_suite "$0"

TOOL="$REPO_ROOT/rg-abstracts"

require_command rg

setup_abstracts() {
  local dir="$1"
  printf '%s\n' "This paper discusses joint action and planning." > "$dir/butterfill:2019_goals.md"
  printf '%s\n' "This abstract concerns visual attention." > "$dir/other:2020_attention.md"
  printf '%s\n' "Not searched by default." > "$dir/notes.txt"
}

finds_matching_abstract() {
  with_tmpdir abstracts_dir _finds_matching_abstract
}

_finds_matching_abstract() {
  setup_abstracts "$abstracts_dir"
  local out
  out=$(ABSTRACTS_DIR="$abstracts_dir" "$TOOL" -l -i "joint action")
  [[ "$out" == "butterfill:2019_goals.md" ]]
}

preserves_context_flags() {
  with_tmpdir abstracts_dir _preserves_context_flags
}

_preserves_context_flags() {
  setup_abstracts "$abstracts_dir"
  local out
  out=$(ABSTRACTS_DIR="$abstracts_dir" "$TOOL" -n -C 1 "visual attention")
  rg -q "other:2020_attention.md:1:This abstract concerns visual attention." <<< "$out"
}

rejects_absolute_paths() {
  with_tmpdir abstracts_dir _rejects_absolute_paths
}

_rejects_absolute_paths() {
  setup_abstracts "$abstracts_dir"
  local rc=0
  set +e
  ABSTRACTS_DIR="$abstracts_dir" "$TOOL" -- foo /etc >/dev/null 2>"$abstracts_dir/err.txt"
  rc=$?
  set -e
  test "$rc" -eq 2 && rg -q "absolute paths not allowed" "$abstracts_dir/err.txt"
}

it "finds matching abstract filename" finds_matching_abstract
it "preserves ordinary ripgrep context flags" preserves_context_flags
it "rejects absolute paths with an error" rejects_absolute_paths

complete_suite
