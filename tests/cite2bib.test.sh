#!/usr/bin/env bash
set -euo pipefail

# Tests for cite2bib focusing on macOS-compatible regex and fallback scan

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)
cd "$REPO_ROOT"

source "$REPO_ROOT/tests/lib/test_helpers.sh"
test_suite "$0"

TOOL="$REPO_ROOT/cite2bib"

require_command rg sed awk

# Create a temp bib file
TMP_BIB=$(mktemp -t tmp_rovodev_cite2bib_bib.XXXX.bib)
trap 'rm -f "$TMP_BIB"' EXIT
cat > "$TMP_BIB" <<'BIB'
@article{borg:2024_acting,
  author={Borg, Emma},
  year={2024},
  title={Acting for Reasons}
}
@article{vesper:2012_jumping,
  author={Vesper, Christina},
  year={2012},
  title={Jumping}
}
BIB

run_output() {
  local cmd
  printf -v cmd '%q ' "$@"
  bash -lc "$cmd"
}

has_line_matching() {
  local pattern="$1"; shift
  local out
  if ! out=$(run_output "$@" 2>/dev/null); then
    return 1
  fi
  rg -q "$pattern" <<< "$out"
}

# 1) Exact key match succeeds
it "exact key match works" \
  has_line_matching '^@' \
  BIB_FILE="$TMP_BIB" "$TOOL" "borg:2024_acting"

# 2) Non-existent key should not error; should print not found message and exit non-zero
not_found_ok() {
  local out rc
  rm -f missing-keys.txt
  set +e
  out=$(BIB_FILE="$TMP_BIB" "$TOOL" "acting" 2>&1)
  rc=$?
  set -e
  rg -q 'MISSING cite2bib: acting \(normalized: acting\) in ' <<< "$out" && \
  test $rc -eq 1 && rg -q '^acting$' missing-keys.txt
}

it "non-existent key prints standardized MISSING message, logs key, and exits 1" not_found_ok

# 3) Normalized key match (colons removed)
it "normalized key fallback works" \
  has_line_matching '^@' \
  BIB_FILE="$TMP_BIB" "$TOOL" "vesper2012_jumping"

# 4) Force POSIX awk path
it "portable awk path works when forced" \
  has_line_matching '^@' \
  CITE2BIB_AWK_IMPL=awk BIB_FILE="$TMP_BIB" "$TOOL" "vesper2012_jumping"

# 5) Force gawk path when available
if command -v gawk >/dev/null 2>&1; then
  it "gawk path works when forced" \
    has_line_matching '^@' \
    CITE2BIB_AWK_IMPL=gawk BIB_FILE="$TMP_BIB" "$TOOL" "vesper2012_jumping"
else
  skip "gawk path works when forced" "gawk not found"
fi

complete_suite
