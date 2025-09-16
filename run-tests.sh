#!/usr/bin/env bash
set -euo pipefail

# Run all test scripts in tests/*.sh

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
cd "$REPO_ROOT"

shopt -s nullglob
tests=(tests/*.sh)
shopt -u nullglob

if [[ ${#tests[@]} -eq 0 ]]; then
  echo "No tests found in tests/." >&2
  exit 2
fi

pass=0
fail=0
skip=0

for t in "${tests[@]}"; do
  echo "=== Running: $t ==="
  set +e
  bash "$t"
  rc=$?
  set -e
  case "$rc" in
    0) echo "=== PASS: $t ==="; pass=$((pass+1)) ;;
    2) echo "=== SKIP: $t ==="; skip=$((skip+1)) ;;
    *) echo "=== FAIL: $t (rc=$rc) ==="; fail=$((fail+1)) ;;
  esac
done

echo "SUMMARY: $pass passed, $fail failed, $skip skipped"

if [[ $fail -gt 0 ]]; then
  exit 1
fi
exit 0

