#!/usr/bin/env bash
set -euo pipefail

# Simple tests for new CSL-JSON based find-bib

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)
cd "$REPO_ROOT"

source "$REPO_ROOT/tests/lib/test_helpers.sh"
test_suite "$0"

TOOL="./find-bib"
FIXTURE_JSON="tests/fixtures/phd_biblio.json"

# Ensure local tools are discoverable (cite2bib) for --cat integration
export PATH="$REPO_ROOT:$PATH"

require_command jq rg

run_output() {
  local cmd
  printf -v cmd '%q ' "$@"
  bash -lc "PATH=$(printf '%q' "$REPO_ROOT"):\$PATH; $cmd"
}

has_line_matching() {
  local pattern="$1"; shift
  local out
  if ! out=$(run_output "$@" 2>/dev/null); then
    return 1
  fi
  rg -q "$pattern" <<< "$out"
}

has_n_lines() {
  local n="$1"; shift
  local out
  if ! out=$(run_output "$@" 2>/dev/null); then
    return 1
  fi
  test "$(printf '%s\n' "$out" | sed '/^$/d' | wc -l | tr -d ' ')" -eq "$n"
}

# 1) Field filters: Steward 2009 Animal Agency
it "finds Steward 2009 Animal Agency by field filters" \
  has_line_matching '^steward:2009_animal$' \
  BIB_JSON="$FIXTURE_JSON" "$TOOL" --author steward --year 2009 --title animal

# 2) Abstract/topic search: motor (find smith 2021)
it "finds Smith 2021 by abstract contains 'motor'" \
  has_line_matching '^smith:2021_joint$' \
  BIB_JSON="$FIXTURE_JSON" "$TOOL" --abstract motor

# 3) limit parameter
# 3) cat output via cite2bib (using sample.bib fixture)
if command -v cite2bib >/dev/null 2>&1; then
  it "emits BibTeX via --cat for smith:2021_joint" \
    has_line_matching '^@\w+\{smith:2021_joint,' \
    BIB_FILE="tests/fixtures/sample.bib" BIB_JSON="$FIXTURE_JSON" "$TOOL" --author smith --cat

  cat_mode_fails_when_cite2bib_fails() {
    local tmp_bib out rc
    tmp_bib=$(mktemp)
    cat > "$tmp_bib" <<'BIB'
@article{not:the_key,
  title = {Placeholder}
}
BIB
    set +e
    out=$(BIB_FILE="$tmp_bib" BIB_JSON="$FIXTURE_JSON" "$TOOL" --author smith --cat 2>&1)
    rc=$?
    set -e
    rm -f "$tmp_bib"
    [[ $rc -eq 1 ]] && rg -q '^MISSING cite2bib: smith:2021_joint' <<< "$out"
  }

  it "returns non-zero in --cat mode when cite2bib cannot emit entries" cat_mode_fails_when_cite2bib_fails
else
  skip "emits BibTeX via --cat for smith:2021_joint" "cite2bib not found"
fi

complete_suite
