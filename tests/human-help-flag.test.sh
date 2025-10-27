#!/usr/bin/env bash
set -euo pipefail

# Shared tests for --help vs --human behavior across CLI tools

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)
cd "$REPO_ROOT"

source "$REPO_ROOT/tests/lib/test_helpers.sh"
test_suite "$0"

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

require_command rg

help_excludes_human() {
  local tool_path="$1"
  local out
  if ! out=$("$tool_path" --help); then
    return 1
  fi
  rg -q 'Usage:' <<<"$out" && ! rg -q '\-\-human' <<<"$out"
}

human_includes_environment() {
  local tool_path="$1"
  local out
  if ! out=$("$tool_path" --human); then
    return 1
  fi
  rg -q 'Environment:' <<<"$out"
}

human_conflicts_error() {
  local tool_path="$1"
  local rc=0
  local err
  set +e
  err=$("$tool_path" --human extra 2>&1)
  rc=$?
  set -e
  [[ $rc -eq 2 ]] && rg -q 'cannot be combined' <<<"$err"
}

human_precedes_help() {
  local tool_path="$1"
  local out
  if ! out=$("$tool_path" --human --help); then
    return 1
  fi
  rg -q 'Environment:' <<<"$out"
}

for tool in "${TOOLS[@]}"; do
  TOOL_PATH="$REPO_ROOT/$tool"
  if [[ ! -x "$TOOL_PATH" ]]; then
    skip_suite "missing tool $tool"
  fi
  it "$tool --help hides --human" help_excludes_human "$TOOL_PATH"
  it "$tool --human prints environment section" human_includes_environment "$TOOL_PATH"
  it "$tool --human rejects other args" human_conflicts_error "$TOOL_PATH"
  it "$tool --human --help prefers human output" human_precedes_help "$TOOL_PATH"
done

complete_suite
