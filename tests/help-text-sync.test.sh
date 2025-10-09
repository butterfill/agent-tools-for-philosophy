#!/usr/bin/env bash
set -euo pipefail

# Verify that each tool's --help / --human output matches the canonical text in help-text/.
# When a mismatch occurs we surface a structural diff using difft or difftastic (falling
# back to diff -u only if neither tool is installed).

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)
cd "$REPO_ROOT"

HELP_DIR="$REPO_ROOT/help-text"
if [[ ! -d "$HELP_DIR" ]]; then
  echo "help-text directory not found: $HELP_DIR" >&2
  exit 2
fi

TOOLS=(
  cat-sources
  cite2bib
  cite2md
  cite2pdf
  draft2keys
  fd-sources
  find-bib
  path2key
  rg-sources
)

pass=0
fail=0

have_difft=false
have_difftastic=false
if command -v difft >/dev/null 2>&1; then
  have_difft=true
fi
if command -v difftastic >/dev/null 2>&1; then
  have_difftastic=true
fi

show_diff() {
  local expected="$1"
  local actual="$2"
  echo "  --- diff (expected vs actual) ---"
  if $have_difft; then
    difft --label expected "$expected" --label actual "$actual" || true
  elif $have_difftastic; then
    difftastic "$expected" "$actual" || true
  else
    diff -u "$expected" "$actual" || true
  fi
  echo "  --- end diff ---"
}

it() {
  local name="$1"; shift
  echo "TEST: $name"
  if "$@"; then
    echo "  PASS"
    pass=$((pass+1))
  else
    echo "  FAIL ($name)" >&2
    fail=$((fail+1))
  fi
}

check_help_output() {
  local tool="$1"
  local mode="$2"    # help or human
  local flag
  local expected_file="$HELP_DIR/${tool}-${mode}.txt"
  local tool_path="$REPO_ROOT/$tool"

  case "$mode" in
    help) flag="--help" ;;
    human) flag="--human" ;;
    *) echo "unknown mode: $mode" >&2; return 1 ;;
  esac

  if [[ ! -x "$tool_path" ]]; then
    echo "missing executable: $tool_path" >&2
    return 1
  fi

  if [[ ! -f "$expected_file" ]]; then
    echo "missing expected text: $expected_file" >&2
    return 1
  fi

  local actual_file
  actual_file=$(mktemp "$REPO_ROOT/.help-text.actual.XXXXXX")

  if ! "$tool_path" "$flag" >"$actual_file"; then
    echo "$tool $flag failed" >&2
    show_diff "$expected_file" "$actual_file"
    rm -f "$actual_file"
    return 1
  fi

  if ! cmp -s "$expected_file" "$actual_file"; then
    echo "$tool $flag output differs from help-text/${tool}-${mode}.txt" >&2
    show_diff "$expected_file" "$actual_file"
    rm -f "$actual_file"
    return 1
  fi

  rm -f "$actual_file"
  return 0
}

for tool in "${TOOLS[@]}"; do
  it "$tool --help matches help-text" check_help_output "$tool" "help"
  it "$tool --human matches help-text" check_help_output "$tool" "human"
done

echo "RESULT: $pass passed, $fail failed"
[[ "$fail" -eq 0 ]]
