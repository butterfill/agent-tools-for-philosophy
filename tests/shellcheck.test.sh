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

declare -a scripts=()
while IFS= read -r path; do
  [[ -f "$path" ]] || continue
  case "$path" in
    *.sh)
      scripts[${#scripts[@]}]="$path"
      ;;
    *)
      first_line=$(head -n 1 -- "$path" 2>/dev/null || true)
      if printf '%s\n' "$first_line" | grep -Eq '^#!.*([/[:space:]])(bash|dash|ash|ksh|zsh|sh)([[:space:]]|$)'; then
        scripts[${#scripts[@]}]="$path"
      fi
      ;;
  esac
done < <(git ls-files | LC_ALL=C sort)

lint_shell_scripts() {
  shellcheck --severity=warning -- "${scripts[@]}"
}

if [[ "${#scripts[@]}" -eq 0 ]]; then
  skip "shellcheck passes on tracked shell scripts" "no shell scripts found to lint"
else
  it "shellcheck passes on tracked shell scripts" lint_shell_scripts
fi

complete_suite
