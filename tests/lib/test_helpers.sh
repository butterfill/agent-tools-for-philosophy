#!/usr/bin/env bash
set -euo pipefail

# Shared helpers for shell test suites.
#
# Contract for tests:
# - Set REPO_ROOT before calling helpers that execute repository tools.
# - run_output intentionally evaluates commands through bash -lc so call sites can
#   use environment-prefixed commands such as BIB_FILE=... "$TOOL" key.
# - run_output puts REPO_ROOT first on PATH so tests prefer repo-local tools.
# - with_tmpdir, with_tmpfile, run_in_tmpdir, and it_in_tmpdir are the preferred
#   APIs for temporary resources; test scratch files must not be written to the
#   repository root.
# - run_in_tmpdir/it_in_tmpdir run the command from an isolated temporary cwd
#   and pass the temp directory path as the command's first argument.

if [[ -z "${BASH_VERSION:-}" ]]; then
  echo "test_helpers.sh requires bash" >&2
  exit 1
fi

__suite_path=""
__suite_started=0
__suite_completed=0
__suite_pass=0
__suite_fail=0
__suite_skip=0
__suite_skipped_entire=0
__suite_skip_reason=""
__suite_start_seconds=0
declare -a __suite_failure_blocks=()
declare -a __suite_failure_lines=()

_suite_require_started() {
  if [[ "$__suite_started" -ne 1 ]]; then
    echo "test_helpers: call test_suite \"\$0\" before declaring tests" >&2
    exit 1
  fi
}

test_suite() {
  if [[ "$__suite_started" -eq 1 ]]; then
    echo "test_helpers: test_suite already called for $__suite_path" >&2
    exit 1
  fi
  __suite_path="$1"
  __suite_started=1
  __suite_completed=0
  __suite_pass=0
  __suite_fail=0
  __suite_skip=0
  __suite_skipped_entire=0
  __suite_skip_reason=""
  __suite_start_seconds=$SECONDS
  __suite_failure_blocks=()
  __suite_failure_lines=()
}

it() {
  _suite_require_started
  if [[ $# -lt 2 ]]; then
    echo "test_helpers: it requires a description and a command" >&2
    exit 1
  fi

  local description="$1"
  shift

  local tmp
  tmp=$(mktemp "/tmp/testcase.${RANDOM}.XXXXXX")
  # Ensure cleanup even if the test aborts.
  cleanup_tmp() { rm -f "$tmp"; }
  trap cleanup_tmp RETURN

  set +e
  "$@" >"$tmp" 2>&1
  local rc=$?
  set -e

  if [[ $rc -eq 0 ]]; then
    printf '  ok %s\n' "$description"
    __suite_pass=$((__suite_pass + 1))
  else
    printf '  not ok %s\n' "$description"
    __suite_fail=$((__suite_fail + 1))
    if [[ -s "$tmp" ]]; then
      while IFS= read -r line; do
        printf '    %s\n' "$line"
      done <"$tmp"
    fi
    local block="  not ok $description"
    if [[ -s "$tmp" ]]; then
      block+=$'\n'"$(sed 's/^/    /' "$tmp")"
    fi
    __suite_failure_blocks+=("$block")
    __suite_failure_lines+=("  not ok $description")
  fi

  trap - RETURN
  rm -f "$tmp"
}

skip() {
  _suite_require_started
  if [[ $# -lt 2 ]]; then
    echo "test_helpers: skip requires a description and reason" >&2
    exit 1
  fi
  local description="$1"
  local reason="$2"
  printf '  skip %s (%s)\n' "$description" "$reason"
  __suite_skip=$((__suite_skip + 1))
}

skip_suite() {
  _suite_require_started
  local reason="${1:-skipped}"
  __suite_skipped_entire=1
  __suite_skip_reason="$reason"
  complete_suite
}

require_command() {
  if [[ $# -eq 0 ]]; then
    echo "test_helpers: require_command expects at least one command" >&2
    exit 1
  fi
  local cmd
  for cmd in "$@"; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      skip_suite "missing dependency: $cmd"
    fi
  done
}

run_output() {
  local cmd
  printf -v cmd '%q ' "$@"
  PATH="$REPO_ROOT:$PATH" bash -lc "$cmd"
}

has_line_matching() {
  local pattern="$1"
  shift
  local out
  if ! out=$(run_output "$@" 2>/dev/null); then
    return 1
  fi
  rg -q "$pattern" <<< "$out"
}

has_n_lines() {
  local expected="$1"
  shift
  local out
  if ! out=$(run_output "$@" 2>/dev/null); then
    return 1
  fi
  [[ "$(printf '%s\n' "$out" | sed '/^$/d' | wc -l | tr -d ' ')" == "$expected" ]]
}

with_tmpdir() {
  if [[ $# -lt 1 ]]; then
    echo "test_helpers: with_tmpdir command..." >&2
    exit 1
  fi

  local dir rc
  dir=$(mktemp -d "/tmp/test.${RANDOM}.XXXXXX")

  local restore_errexit=0
  case "$-" in
    *e*) restore_errexit=1 ;;
  esac

  set +e
  "$@" "$dir"
  rc=$?

  rm -rf -- "$dir"
  if [[ "$restore_errexit" -eq 1 ]]; then
    set -e
  fi
  return "$rc"
}

run_in_tmpdir() {
  if [[ $# -lt 1 ]]; then
    echo "test_helpers: run_in_tmpdir command..." >&2
    exit 1
  fi

  local cmd="$1"
  shift
  local dir rc
  dir=$(mktemp -d "/tmp/test.${RANDOM}.XXXXXX")

  local restore_errexit=0
  case "$-" in
    *e*) restore_errexit=1 ;;
  esac

  set +e
  (cd "$dir" && "$cmd" "$dir" "$@")
  rc=$?

  rm -rf -- "$dir"
  if [[ "$restore_errexit" -eq 1 ]]; then
    set -e
  fi
  return "$rc"
}

it_in_tmpdir() {
  if [[ $# -lt 2 ]]; then
    echo "test_helpers: it_in_tmpdir requires a description and a command" >&2
    exit 1
  fi

  local description="$1"
  shift
  it "$description" run_in_tmpdir "$@"
}

with_tmpfile() {
  if [[ $# -lt 1 ]]; then
    echo "test_helpers: with_tmpfile command..." >&2
    exit 1
  fi

  local file rc
  file=$(mktemp "/tmp/test.${RANDOM}.XXXXXX")

  local restore_errexit=0
  case "$-" in
    *e*) restore_errexit=1 ;;
  esac

  set +e
  "$@" "$file"
  rc=$?

  rm -f -- "$file"
  if [[ "$restore_errexit" -eq 1 ]]; then
    set -e
  fi
  return "$rc"
}

suite_failures_for_recap() {
  # Prints unique failure lines (first line only) for harness recap.
  if [[ ${#__suite_failure_lines[@]} -eq 0 ]]; then
    return 0
  fi
  local -A seen=()
  local line
  for line in "${__suite_failure_lines[@]}"; do
    if [[ -z "${seen[$line]:-}" ]]; then
      printf '%s\n' "$line"
      seen["$line"]=1
    fi
  done
}

complete_suite() {
  _suite_require_started
  if [[ "$__suite_completed" -eq 1 ]]; then
    return
  fi
  __suite_completed=1

  if [[ "$__suite_skipped_entire" -eq 1 ]]; then
    printf 'SUITE %s: skipped (%s)\n' "$__suite_path" "$__suite_skip_reason"
    if [[ -n "${HARNESS_FAILURE_FILE:-}" ]]; then
      : >"$HARNESS_FAILURE_FILE"
    fi
    exit 2
  fi

  printf 'SUITE %s: %d passed, %d failed, %d skipped\n' \
    "$__suite_path" "$__suite_pass" "$__suite_fail" "$__suite_skip"

  if [[ "$__suite_fail" -gt 0 ]]; then
    local block
    for block in "${__suite_failure_blocks[@]}"; do
      printf '%s\n' "$block"
    done
    if [[ -n "${HARNESS_FAILURE_FILE:-}" ]]; then
      suite_failures_for_recap >"$HARNESS_FAILURE_FILE"
    fi
    exit 1
  fi

  if [[ -n "${HARNESS_FAILURE_FILE:-}" ]]; then
    : >"$HARNESS_FAILURE_FILE"
  fi

  exit 0
}
