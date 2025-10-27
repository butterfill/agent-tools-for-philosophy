#!/usr/bin/env bash
set -euo pipefail

# Run shellcheck on every shell script tracked in the repository.

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)
cd "$REPO_ROOT"

source "$REPO_ROOT/tests/lib/test_helpers.sh"
test_suite "$0"

require_command git

if ! command -v shellcheck >/dev/null 2>&1; then
  skip_suite "shellcheck not found; install shellcheck to enable this test"
fi

mapfile -d '' scripts < <(
  git ls-files -z | while IFS= read -r -d '' path; do
    [[ -f "$path" ]] || continue
    case "$path" in
      *.sh) printf '%s\0' "$path" ;;
      *)
        if IFS= read -r first_line < "$path"; then
          if [[ "$first_line" =~ ^#!.*/(bash|dash|ash|ksh|zsh|sh)([[:space:]]|$) ]] || [[ "$first_line" =~ ^#!.*[[:space:]](bash|dash|ash|ksh|zsh|sh)([[:space:]]|$) ]]; then
            printf '%s\0' "$path"
          fi
        fi
        ;;
    esac
  done | LC_ALL=C sort -z
)

lint_shell_scripts() {
  shellcheck --severity=warning -- "${scripts[@]}"
}

if [[ "${#scripts[@]}" -eq 0 ]]; then
  skip "shellcheck passes on tracked shell scripts" "no shell scripts found to lint"
else
  it "shellcheck passes on tracked shell scripts" lint_shell_scripts
fi

complete_suite
