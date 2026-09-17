#!/usr/bin/env bash
set -euo pipefail

# Tests for ReferenceCatalog-backed find-bib.

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)
cd "$REPO_ROOT"

source "$REPO_ROOT/tests/lib/test_helpers.sh"
test_suite "$0"

TOOL="$REPO_ROOT/find-bib"
FIXTURE_JSON="$REPO_ROOT/tests/fixtures/phd_biblio.json"
FIXTURE_ZOTERO="$REPO_ROOT/tests/fixtures/zotero-export.json"

# Ensure local tools are discoverable (cite2bib) for --cat integration.
export PATH="$REPO_ROOT:$PATH"

require_command python3 rg

# find-bib is a canonical field-filter consumer, not a fuzzy-search consumer.
# Shadow rapidfuzz with a module that raises if imported so this remains true
# even on developer/CI machines where the real dependency is installed.
_field_filters_do_not_import_rapidfuzz() {
  local tmpdir="$1"
  local out
  cat > "$tmpdir/rapidfuzz.py" <<'PY'
raise ModuleNotFoundError("rapidfuzz intentionally blocked for find-bib field-filter test")
PY
  out=$(PYTHONPATH="$tmpdir${PYTHONPATH:+:$PYTHONPATH}" \
    BIB_JSON="$FIXTURE_JSON" ZOTERO_JSON="$FIXTURE_ZOTERO" \
    "$TOOL" --author steward --year 2009 --title animal)
  rg -q '^steward:2009_animal$' <<< "$out"
}
it_in_tmpdir "field filters do not import rapidfuzz" _field_filters_do_not_import_rapidfuzz

# 1) Existing field-filter behavior is preserved over canonical entries.
it "finds Steward 2009 Animal Agency by field filters" \
  has_line_matching '^steward:2009_animal$' \
  env BIB_JSON="$FIXTURE_JSON" ZOTERO_JSON="$FIXTURE_ZOTERO" \
  "$TOOL" --author steward --year 2009 --title animal

it "finds Smith 2021 by abstract contains motor" \
  has_line_matching '^smith:2021_joint$' \
  env BIB_JSON="$FIXTURE_JSON" ZOTERO_JSON="$FIXTURE_ZOTERO" \
  "$TOOL" --abstract motor

_same_field_filters_are_or() {
  local out
  out=$(BIB_JSON="$FIXTURE_JSON" ZOTERO_JSON="$FIXTURE_ZOTERO" \
    "$TOOL" --author steward --author smith)
  rg -q '^steward:2009_animal$' <<< "$out" \
    && rg -q '^steward:2010_followup$' <<< "$out" \
    && rg -q '^smith:2021_joint$' <<< "$out"
}
it "ORs repeated filters within a field" _same_field_filters_are_or

# 2) Source membership/precedence comes from ReferenceCatalog.
it "includes secondary-only records from the canonical union" \
  has_line_matching '^new:2026_secondary$' \
  env BIB_JSON="$FIXTURE_JSON" ZOTERO_JSON="$FIXTURE_ZOTERO" \
  "$TOOL" --author new --title secondary

_primary_metadata_wins() {
  local out rc
  set +e
  out=$(BIB_JSON="$FIXTURE_JSON" ZOTERO_JSON="$FIXTURE_ZOTERO" \
    "$TOOL" --title "secondary metadata should not win" 2>&1)
  rc=$?
  set -e
  [[ $rc -eq 1 && -z "$out" ]]
}
it "uses primary metadata for shared citation keys" _primary_metadata_wins

it "keeps the primary shared record discoverable by primary metadata" \
  has_line_matching '^steward:2009_animal$' \
  env BIB_JSON="$FIXTURE_JSON" ZOTERO_JSON="$FIXTURE_ZOTERO" \
  "$TOOL" --title "animal agency"

# 3) Usage and catalogue readiness errors remain exit 2.
_missing_filter_value_is_usage_error() {
  local out rc
  set +e
  out=$(BIB_JSON="$FIXTURE_JSON" ZOTERO_JSON="$FIXTURE_ZOTERO" "$TOOL" --author 2>&1)
  rc=$?
  set -e
  [[ $rc -eq 2 ]] && rg -q -- '--author requires a value' <<< "$out"
}
it "rejects a field flag without a value" _missing_filter_value_is_usage_error

_missing_primary_is_configuration_error() {
  local tmpdir="$1"
  local out rc
  set +e
  out=$(BIB_JSON="$tmpdir/missing-primary.json" ZOTERO_JSON="$FIXTURE_ZOTERO" "$TOOL" --author steward 2>&1)
  rc=$?
  set -e
  [[ $rc -eq 2 ]] && rg -q 'Primary bibliography unavailable' <<< "$out"
}
it_in_tmpdir "reports unavailable canonical primary data as configuration error" _missing_primary_is_configuration_error

# 4) --cat still delegates artifact production to cite2bib.
if command -v cite2bib >/dev/null 2>&1; then
  it "emits BibTeX via --cat for smith:2021_joint" \
    has_line_matching '^@\w+\{smith:2021_joint,' \
    env BIB_FILE="$REPO_ROOT/tests/fixtures/sample.bib" BIB_JSON="$FIXTURE_JSON" ZOTERO_JSON="$FIXTURE_ZOTERO" \
    "$TOOL" --author smith --cat

  _cat_mode_fails_when_cite2bib_fails() {
    local tmpdir="$1"
    local tmp_bib="$tmpdir/missing-entry.bib"
    local out rc
    cat > "$tmp_bib" <<'BIB'
@article{not:the_key,
  title = {Placeholder}
}
BIB
    set +e
    out=$(BIB_FILE="$tmp_bib" BIB_JSON="$FIXTURE_JSON" ZOTERO_JSON="$FIXTURE_ZOTERO" \
      "$TOOL" --author smith --cat 2>&1)
    rc=$?
    set -e
    [[ $rc -eq 1 ]] && rg -q '^MISSING cite2bib: smith:2021_joint' <<< "$out"
  }
  it_in_tmpdir "returns non-zero in --cat mode when cite2bib cannot emit entries" _cat_mode_fails_when_cite2bib_fails

  _secondary_only_cat_fails_naturally_without_bibtex() {
    local tmpdir="$1"
    local out rc
    [[ -d "$tmpdir" ]] || return 1
    set +e
    out=$(BIB_FILE="$REPO_ROOT/tests/fixtures/sample.bib" BIB_JSON="$FIXTURE_JSON" ZOTERO_JSON="$FIXTURE_ZOTERO" \
      "$TOOL" --author new --cat 2>&1)
    rc=$?
    set -e
    [[ $rc -eq 1 ]] && rg -q '^MISSING cite2bib: new:2026_secondary' <<< "$out"
  }
  it_in_tmpdir "does not invent BibTeX for secondary-only catalogue records" _secondary_only_cat_fails_naturally_without_bibtex
else
  skip "emits BibTeX via --cat for smith:2021_joint" "cite2bib not found"
  skip "returns non-zero in --cat mode when cite2bib cannot emit entries" "cite2bib not found"
  skip "does not invent BibTeX for secondary-only catalogue records" "cite2bib not found"
fi

complete_suite
