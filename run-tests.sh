#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
cd "$REPO_ROOT"

usage() {
  cat <<'EOF'
Usage: ./run-tests.sh [--list] [--match <pattern>] [suites...]

Options:
  --list              List matching suites without executing them.
  --match <pattern>   Run suites whose basename matches the regex/substring.
  --help              Show this message.

Examples:
  ./run-tests.sh
  ./run-tests.sh tests/find-bib.test.sh
  ./run-tests.sh --match "find-bib"
EOF
}

match_pattern=""
list_only=0
declare -a requested_suites=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --match)
      shift
      if [[ $# -eq 0 ]]; then
        echo "Missing argument for --match" >&2
        exit 2
      fi
      match_pattern="$1"
      ;;
    --list)
      list_only=1
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    --)
      shift
      while [[ $# -gt 0 ]]; do
        requested_suites+=("$1")
        shift
      done
      break
      ;;
    -*)
      echo "Unknown option: $1" >&2
      exit 2
      ;;
    *)
      requested_suites+=("$1")
      ;;
  esac
  shift
done

discover_all_suites() {
  shopt -s nullglob
  local found=(tests/*.sh)
  shopt -u nullglob
  if [[ ${#found[@]} -eq 0 ]]; then
    echo "No test suites found under tests/." >&2
    exit 2
  fi
  printf '%s\n' "${found[@]}" | LC_ALL=C sort
}

declare -a suites=()

if [[ ${#requested_suites[@]} -gt 0 ]]; then
  suites=("${requested_suites[@]}")
else
  mapfile -t suites < <(discover_all_suites)
fi

if [[ -n "$match_pattern" ]]; then
  declare -a filtered=()
  for suite in "${suites[@]}"; do
    local_name=$(basename "$suite")
    if [[ "$local_name" =~ $match_pattern ]]; then
      filtered+=("$suite")
    fi
  done
  suites=("${filtered[@]}")
fi

if [[ ${#suites[@]} -eq 0 ]]; then
  echo "No test suites selected." >&2
  exit 2
fi

if [[ "$list_only" -eq 1 ]]; then
  printf '%s\n' "${suites[@]}"
  exit 0
fi

SECONDS=0

total_suites=0
passed_suites=0
failed_suites=0
skipped_suites=0
declare -a failure_suite_names=()
declare -a failure_suite_lines=()

for suite in "${suites[@]}"; do
  if [[ ! -f "$suite" ]]; then
    echo "RUN $suite"
    echo "SUITE $suite: skipped (suite file not found)" >&2
    skipped_suites=$((skipped_suites + 1))
    total_suites=$((total_suites + 1))
    continue
  fi

  total_suites=$((total_suites + 1))
  echo "RUN $suite"

  suite_output=$(mktemp)
  failure_file=$(mktemp)

  set +e
  HARNESS_FAILURE_FILE="$failure_file" bash "$suite" >"$suite_output" 2>&1
  suite_rc=$?
  set -e

  cat "$suite_output"
  rm -f "$suite_output"

  failure_lines=""
  if [[ -s "$failure_file" ]]; then
    failure_lines=$(<"$failure_file")
  fi
  rm -f "$failure_file"

  case "$suite_rc" in
    0)
      passed_suites=$((passed_suites + 1))
      ;;
    2)
      skipped_suites=$((skipped_suites + 1))
      ;;
    *)
      failed_suites=$((failed_suites + 1))
      failure_suite_names+=("$suite")
      failure_suite_lines+=("$failure_lines")
      ;;
  esac
done

elapsed=$SECONDS

printf 'TOTAL: %d suites, %d passed, %d failed, %d skipped, duration %ss\n' \
  "$total_suites" "$passed_suites" "$failed_suites" "$skipped_suites" "$elapsed"

if [[ "$failed_suites" -gt 0 ]]; then
  echo "FAILURES:"
  for idx in "${!failure_suite_names[@]}"; do
    suite="${failure_suite_names[$idx]}"
    echo "  $suite"
    lines="${failure_suite_lines[$idx]}"
    if [[ -n "$lines" ]]; then
      while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        if [[ "$line" == "  "* ]]; then
          printf '    %s\n' "${line:2}"
        else
          printf '    %s\n' "$line"
        fi
      done <<< "$lines"
    else
      echo "    (no failing test details reported)"
    fi
  done
fi

if [[ "$failed_suites" -gt 0 ]]; then
  exit 1
fi
exit 0
