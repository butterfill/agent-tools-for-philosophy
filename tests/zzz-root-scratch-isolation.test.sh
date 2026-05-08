#!/usr/bin/env bash
set -euo pipefail

# Regression guard for tests that exercise cwd-sensitive tool side effects.

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)
cd "$REPO_ROOT"

source "$REPO_ROOT/tests/lib/test_helpers.sh"
test_suite "$0"

declare -a ROOT_SCRATCH_FILES=(
  err.txt
  missing-keys.txt
  missing-fulltext.txt
)

remove_root_scratch_files() {
  rm -f -- "${ROOT_SCRATCH_FILES[@]}"
}

assert_no_root_scratch_files() {
  local found=0
  local file
  for file in "${ROOT_SCRATCH_FILES[@]}"; do
    if [[ -e "$file" ]]; then
      echo "repo-root scratch file was created: $file" >&2
      found=1
    fi
  done

  if [[ "$found" -ne 0 ]]; then
    remove_root_scratch_files
    return 1
  fi
}

targeted_suites_do_not_write_root_scratch() {
  local output rc
  declare -a suites=(
    tests/cat-sources.test.sh
    tests/cite2bib.test.sh
    tests/cite2md.test.sh
    tests/cite2md.e2e.test.sh
    tests/cite2pdf.test.sh
    tests/fd-sources.e2e.test.sh
    tests/find-bib.test.sh
    tests/path2key.test.sh
    tests/rg-sources.e2e.test.sh
  )

  remove_root_scratch_files

  set +e
  output=$(./run-tests.sh "${suites[@]}" 2>&1)
  rc=$?
  set -e

  if [[ "$rc" -ne 0 ]]; then
    printf '%s\n' "$output" >&2
    return "$rc"
  fi

  assert_no_root_scratch_files
}

it "targeted suites do not write repo-root scratch files" targeted_suites_do_not_write_root_scratch

complete_suite
