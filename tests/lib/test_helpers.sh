#!/usr/bin/env bash
set -euo pipefail

# Shared helpers for shell test suites.
# Provides a small DSL for consistent reporting and diagnostics.

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

with_tmpdir() {
  if [[ $# -lt 2 ]]; then
    echo "test_helpers: with_tmpdir VAR command..." >&2
    exit 1
  fi

  local var_name="$1"
  shift
  local dir
  dir=$(mktemp -d "/tmp/${var_name}.${RANDOM}.XXXXXX")
  printf -v "$var_name" '%s' "$dir"
  set +e
  "$@"
  local rc=$?
  set -e
  rm -rf "$dir"
  return "$rc"
}

capture() {
  if [[ $# -lt 2 ]]; then
    echo "test_helpers: capture VAR command..." >&2
    exit 1
  fi
  local var_name="$1"
  shift
  local output
  set +e
  output="$("$@" 2>&1)"
  local rc=$?
  set -e
  printf -v "$var_name" '%s' "$output"
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
