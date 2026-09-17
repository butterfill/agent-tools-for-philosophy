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

# Print four lines: canonical key, author filter, year filter, title filter.
# The selector independently applies the catalogue's documented primary identity
# rule (citation-key, falling back to id; first occurrence wins). It deliberately
# does not hard-code a mutable personal-library record.
_select_real_case() {
  local mode="$1"
  BIB_JSON="$BIB_JSON_PATH" ZOTERO_JSON="$ZOTERO_JSON_PATH" BIB_FILE="$BIB_FILE_PATH" \
    python3 - "$mode" <<'PY'
import json
import os
import re
import sys
from pathlib import Path

mode = sys.argv[1]


def load_rows(path: str, *, optional: bool = False):
    try:
        data = json.loads(Path(path).read_text(encoding="utf-8"))
    except FileNotFoundError:
        if optional:
            return []
        raise
    rows = data if isinstance(data, list) else data.get("items") if isinstance(data, dict) else None
    if not isinstance(rows, list):
        raise SystemExit(f"unsupported CSL-JSON shape in {path}")
    seen = set()
    result = []
    for row in rows:
        if not isinstance(row, dict):
            continue
        value = row.get("citation-key") or row.get("id")
        if isinstance(value, bool) or not isinstance(value, (str, int, float)):
            continue
        key = str(value).strip()
        if not key or key in seen:
            continue
        seen.add(key)
        result.append((key, row))
    return result


def collapse(value) -> str:
    return re.sub(r"\s+", " ", str(value or "")).strip()


def norm(value) -> str:
    return collapse(value).replace("{", "").replace("}", "").casefold()


def author_text(row) -> str:
    authors = row.get("author")
    if isinstance(authors, list):
        parts = []
        for author in authors:
            if isinstance(author, dict):
                name = ", ".join(
                    part for part in (collapse(author.get("family")), collapse(author.get("given"))) if part
                )
            else:
                name = collapse(author)
            if name:
                parts.append(name)
        return "; ".join(parts)
    if authors is not None:
        return collapse(authors)
    return collapse(row.get("authors"))


def author_filter(row) -> str:
    authors = row.get("author")
    if isinstance(authors, list):
        for author in authors:
            if isinstance(author, dict):
                candidate = collapse(author.get("family")) or collapse(author.get("given"))
            else:
                candidate = collapse(author)
            if candidate:
                return candidate
    return author_text(row)


def year_text(row) -> str:
    issued = row.get("issued")
    if isinstance(issued, dict):
        parts = issued.get("date-parts")
        if isinstance(parts, list) and parts and isinstance(parts[0], list) and parts[0]:
            return collapse(parts[0][0])
        issued = issued.get("literal")
    match = re.search(r"(?:19|20)\d{2}", collapse(issued))
    return match.group(0) if match else ""


def fields(row):
    return author_filter(row), year_text(row), collapse(row.get("title"))


def emit(key, row):
    author, year, title = fields(row)
    print(key)
    print(author)
    print(year)
    print(title)


primary = load_rows(os.environ["BIB_JSON"])
secondary = load_rows(os.environ.get("ZOTERO_JSON", ""), optional=True) if os.environ.get("ZOTERO_JSON") else []
primary_keys = {key for key, _ in primary}
canonical = primary + [(key, row) for key, row in secondary if key not in primary_keys]

if mode == "field":
    for key, row in primary:
        author, year, title = fields(row)
        if author and year and title:
            emit(key, row)
            raise SystemExit(0)
    raise SystemExit("no primary record with author/year/title fields")

if mode != "cat":
    raise SystemExit(f"unknown selector mode: {mode}")

bib_path = os.environ.get("BIB_FILE", "")
if not bib_path or not Path(bib_path).is_file():
    raise SystemExit(f"BibTeX file not found: {bib_path}")
bib_text = Path(bib_path).read_text(encoding="utf-8", errors="replace")
bib_keys = re.findall(r"(?m)^[ \t]*@[A-Za-z]+\{([^,\r\n]+),", bib_text)
bib_exact = set(bib_keys)
bib_compact = {key.replace(":", "") for key in bib_keys}


def in_bib(key: str) -> bool:
    return key in bib_exact or key.replace(":", "") in bib_compact


def matches(row, author, year, title) -> bool:
    return (
        norm(author) in norm(author_text(row))
        and norm(year) in norm(year_text(row))
        and norm(title) in norm(row.get("title"))
    )


for key, row in primary:
    author, year, title = fields(row)
    if not (author and year and title and in_bib(key)):
        continue
    matched_keys = [
        candidate_key
        for candidate_key, candidate_row in canonical
        if matches(candidate_row, author, year, title)
    ]
    if matched_keys and key in matched_keys and all(in_bib(candidate) for candidate in matched_keys):
        emit(key, row)
        raise SystemExit(0)

raise SystemExit("no canonical field-filter case is fully backed by the configured BibTeX file")
PY
}

_parse_selected_case() {
  local selected="$1"
  local count
  count=$(printf '%s\n' "$selected" | wc -l | tr -d ' ')
  if [[ "$count" -ne 4 ]]; then
    echo "selector returned $count lines, expected 4" >&2
    printf '%s\n' "$selected" >&2
    return 1
  fi
  SELECTED_KEY=$(printf '%s\n' "$selected" | sed -n '1p')
  SELECTED_AUTHOR=$(printf '%s\n' "$selected" | sed -n '2p')
  SELECTED_YEAR=$(printf '%s\n' "$selected" | sed -n '3p')
  SELECTED_TITLE=$(printf '%s\n' "$selected" | sed -n '4p')
}

_real_field_filter_roundtrip() {
  local selected out rc
  if ! selected=$(_select_real_case field 2>&1); then
    printf '%s\n' "$selected" >&2
    return 1
  fi
  _parse_selected_case "$selected" || return 1

  set +e
  out=$(BIB_JSON="$BIB_JSON_PATH" ZOTERO_JSON="$ZOTERO_JSON_PATH" \
    "$TOOL" --author "$SELECTED_AUTHOR" --year "$SELECTED_YEAR" --title "$SELECTED_TITLE" 2>&1)
  rc=$?
  set -e
  if [[ $rc -ne 0 ]]; then
    echo "find-bib exited $rc for canonical primary case $SELECTED_KEY" >&2
    printf '%s\n' "$out" >&2
    return 1
  fi
  if ! rg -F -x -q -- "$SELECTED_KEY" <<< "$out"; then
    echo "expected canonical primary key $SELECTED_KEY" >&2
    printf '%s\n' "$out" >&2
    return 1
  fi
}

it "finds a real canonical primary record by author/year/title filters" _real_field_filter_roundtrip

# --cat remains an artifact-layer operation delegated to cite2bib/BIB_FILE. Run
# this case in a temporary cwd so a real-library mismatch can never leak
# cite2bib's missing-keys.txt bookkeeping into the repository root.
_real_cat_roundtrip() {
  local tmpdir="$1"
  local selected out rc
  [[ -d "$tmpdir" ]] || return 1

  if ! selected=$(_select_real_case cat 2>&1); then
    printf '%s\n' "$selected" >&2
    return 1
  fi
  _parse_selected_case "$selected" || return 1

  set +e
  out=$(BIB_FILE="$BIB_FILE_PATH" BIB_JSON="$BIB_JSON_PATH" ZOTERO_JSON="$ZOTERO_JSON_PATH" \
    "$TOOL" --author "$SELECTED_AUTHOR" --year "$SELECTED_YEAR" --title "$SELECTED_TITLE" --cat 2>&1)
  rc=$?
  set -e
  if [[ $rc -ne 0 ]]; then
    echo "find-bib --cat exited $rc for canonical primary case $SELECTED_KEY" >&2
    printf '%s\n' "$out" >&2
    return 1
  fi
  if ! rg -F -q -- "{$SELECTED_KEY," <<< "$out"; then
    echo "expected BibTeX output for $SELECTED_KEY" >&2
    printf '%s\n' "$out" >&2
    return 1
  fi
}

if command -v cite2bib >/dev/null 2>&1 && [[ -f "$BIB_FILE_PATH" ]]; then
  it_in_tmpdir "--cat prints BibTeX for a real canonical primary record" _real_cat_roundtrip
else
  skip "--cat prints BibTeX for a real canonical primary record" "cite2bib or configured BIB_FILE unavailable"
fi

complete_suite
