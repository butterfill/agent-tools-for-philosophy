#!/usr/bin/env bash
set -euo pipefail

# E2E tests for ReferenceCatalog-backed find-bib using the real bibliography.

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)
cd "$REPO_ROOT"

source "$REPO_ROOT/tests/lib/test_helpers.sh"
test_suite "$0"

TOOL="$REPO_ROOT/find-bib"
BIB_JSON_PATH="${BIB_JSON:-$HOME/endnote/phd_biblio.json}"
ZOTERO_JSON_PATH="${ZOTERO_JSON:-$HOME/endnote/zotero-export.json}"
BIB_FILE_PATH="${BIB_FILE:-$HOME/endnote/phd_biblio.bib}"

# Ensure local tools are discoverable (cite2bib) for --cat.
export PATH="$REPO_ROOT:$PATH"

require_command python3 rg

if [[ ! -f "$BIB_JSON_PATH" ]]; then
  skip_suite "canonical primary CSL-JSON not found at $BIB_JSON_PATH"
fi

# Field filtering is now performed over the full canonical union. This known
# primary entry still protects the historical CLI behavior.
it "finds vesper:2012_jumping by author/year/title filters" \
  has_line_matching '^vesper:2012_jumping$' \
  env BIB_JSON="$BIB_JSON_PATH" ZOTERO_JSON="$ZOTERO_JSON_PATH" \
  "$TOOL" --author vesper --year 2013 --title jump

# --cat remains an artifact-layer operation delegated to cite2bib/BIB_FILE.
if command -v cite2bib >/dev/null 2>&1; then
  it "--cat prints a BibTeX entry for vesper:2012_jumping" \
    has_line_matching '^@\w+\{vesper:2012_jumping,' \
    env BIB_FILE="$BIB_FILE_PATH" BIB_JSON="$BIB_JSON_PATH" ZOTERO_JSON="$ZOTERO_JSON_PATH" \
    "$TOOL" --author vesper --year 2013 --title jump --cat
else
  skip "--cat prints a BibTeX entry for vesper:2012_jumping" "cite2bib not on PATH"
fi

complete_suite
