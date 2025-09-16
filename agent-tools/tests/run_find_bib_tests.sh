#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
TOOL="$ROOT_DIR/find-bib"
FIX="$ROOT_DIR/tests/fixtures/sample.bib"

pass() { echo "[PASS] $1"; }
fail() { echo "[FAIL] $1"; exit 1; }

ensure_dep() {
  python3 -c 'import bibtexparser' 2>/dev/null || {
    echo "bibtexparser not installed; installing for tests..." >&2
    python3 -m pip install --user --quiet bibtexparser || true
    python3 -c 'import bibtexparser' 2>/dev/null || {
      echo "Could not import bibtexparser after attempt; skipping tests." >&2
      exit 2
    }
  }
}

ensure_dep

# 1) Basic key match by author+year+title
out=$(BIB_FILE="$FIX" "$TOOL" --author steward --year 2009 --title "animal agency" || true)
[[ "$out" == *"steward:2009_animal"* ]] && pass "author+year+title → key" || fail "author+year+title → key"

# 2) OR within same field (author)
out=$(BIB_FILE="$FIX" "$TOOL" --author nobody --author steward --year 2009)
[[ "$out" == *"steward:2009_animal"* ]] && pass "OR within author values" || fail "OR within author values"

# 3) Abstract AND with multiple flags
out=$(BIB_FILE="$FIX" "$TOOL" --abstract "joint action" --abstract motor)
[[ "$out" == *"smith:2021_joint"* ]] && pass "abstract AND terms" || fail "abstract AND terms"

# 4) --limit
count=$(BIB_FILE="$FIX" "$TOOL" --abstract cognition --limit 1 | wc -l | tr -d ' ')
[[ "$count" == "1" ]] && pass "limit results" || fail "limit results"

# 5) --cat prints entries starting with @
first=$(BIB_FILE="$FIX" "$TOOL" --author steward --cat | head -n1)
[[ "$first" =~ ^@ ]] && pass "--cat prints bib entries" || fail "--cat prints bib entries"

# 6) No matches exit 1
set +e
BIB_FILE="$FIX" "$TOOL" --author "nonexistent author" >/dev/null 2>&1
rc=$?
set -e
[[ $rc -eq 1 ]] && pass "no matches exit 1" || fail "no matches exit 1"

# 7) Missing BIB_FILE exit 2
set +e
BIB_FILE="$ROOT_DIR/tests/fixtures/missing.bib" "$TOOL" --author steward >/dev/null 2>&1
rc=$?
set -e
[[ $rc -eq 2 ]] && pass "missing BIB_FILE exit 2" || fail "missing BIB_FILE exit 2"

echo "All find-bib tests passed."
