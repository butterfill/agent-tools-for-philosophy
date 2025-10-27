#!/usr/bin/env bash
set -euo pipefail

# Run shellcheck on every shell script tracked in the repository.

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)
cd "$REPO_ROOT"

if ! command -v shellcheck >/dev/null 2>&1; then
  echo "WARNING: shellcheck not found; skipping shell lint. Install shellcheck to enable this test." >&2
  exit 2
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

if [[ "${#scripts[@]}" -eq 0 ]]; then
  echo "No shell scripts found to lint." >&2
  exit 0
fi

shellcheck --severity=warning -- "${scripts[@]}"
