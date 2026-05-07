#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)
cd "$REPO_ROOT"

source "$REPO_ROOT/tests/lib/test_helpers.sh"
test_suite "$0"

TOOL="$REPO_ROOT/cite2abs"

require_command rg

setup_abstracts() {
  local dir="$1"
  printf '%s\n' "# Goals" "Joint action abstract contents." > "$dir/butterfill:2019_goals.md"
}

cat_prints_abstract() {
  with_tmpdir _cat_prints_abstract
}

_cat_prints_abstract() {
  local abstracts_dir="$1"
  setup_abstracts "$abstracts_dir"
  local out
  out=$(ABSTRACTS_DIR="$abstracts_dir" "$TOOL" --cat butterfill:2019_goals)
  [[ "$out" == *"Joint action abstract contents."* ]]
}

path_mode_prints_existing_path() {
  with_tmpdir _path_mode_prints_existing_path
}

_path_mode_prints_existing_path() {
  local abstracts_dir="$1"
  setup_abstracts "$abstracts_dir"
  local path
  path=$(ABSTRACTS_DIR="$abstracts_dir" "$TOOL" butterfill:2019_goals)
  [[ -f "$path" && "$path" == "$abstracts_dir/butterfill:2019_goals.md" ]]
}

normalized_filename_resolves() {
  with_tmpdir _normalized_filename_resolves
}

_normalized_filename_resolves() {
  local abstracts_dir="$1"
  printf '%s\n' "Normalized abstract." > "$abstracts_dir/butterfill2019_goals.md"
  local out
  out=$(ABSTRACTS_DIR="$abstracts_dir" "$TOOL" --cat butterfill:2019_goals)
  [[ "$out" == "Normalized abstract." ]]
}

citation_form_resolves() {
  with_tmpdir _citation_form_resolves
}

_citation_form_resolves() {
  local abstracts_dir="$1"
  setup_abstracts "$abstracts_dir"
  local out
  out=$(ABSTRACTS_DIR="$abstracts_dir" "$TOOL" --cat '\citet{butterfill:2019_goals}')
  [[ "$out" == *"Joint action abstract contents."* ]]
}

stdin_resolves() {
  with_tmpdir _stdin_resolves
}

_stdin_resolves() {
  local abstracts_dir="$1"
  setup_abstracts "$abstracts_dir"
  local out
  out=$(printf '%s\n' "butterfill:2019_goals" | ABSTRACTS_DIR="$abstracts_dir" "$TOOL" --cat)
  [[ "$out" == *"Joint action abstract contents."* ]]
}

missing_key_errors() {
  with_tmpdir _missing_key_errors
}

_missing_key_errors() {
  local abstracts_dir="$1"
  setup_abstracts "$abstracts_dir"
  local rc=0
  set +e
  ABSTRACTS_DIR="$abstracts_dir" "$TOOL" --cat missing:key >/dev/null 2>"$abstracts_dir/err.txt"
  rc=$?
  set -e
  test "$rc" -eq 1 && rg -q "MISSING cite2abs: missing:key in $abstracts_dir" "$abstracts_dir/err.txt"
}

it "cat prints abstract contents" cat_prints_abstract
it "path mode prints an existing path" path_mode_prints_existing_path
it "normalized abstract filename resolves" normalized_filename_resolves
it "latex citation form resolves" citation_form_resolves
it "reads keys from stdin" stdin_resolves
it "missing key exits non-zero with useful error" missing_key_errors

complete_suite
