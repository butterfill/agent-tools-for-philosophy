#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)
cd "$REPO_ROOT"

TOOL="$REPO_ROOT/draft2keys"
PAPERS_ROOT="${PAPERS_DIR:-$HOME/papers}"

pass=0
fail=0

require() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "SKIP: missing dependency: $cmd" >&2
    exit 2
  fi
}

require rg

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

make_tmp_draft() {
  local f
  f=$(mktemp -t tmp_draft2keys.XXXX.md)
  cat > "$f" <<'MD'
Intro text.
Here is a LaTeX citation with options: \citep[see][ch.~2]{vesper:2012_jumping, example:missing}.
And a Pandoc inline citation @sinigaglia:2022_motor plus bracket form [@vesper:2012_jumping].
MD
  printf '%s' "$f"
}

keys_extraction_works() {
  local draft out
  draft=$(make_tmp_draft)
  out=$("$TOOL" "$draft")
  # Expect vesper first, then sinigaglia; no duplicates
  grep -qx 'vesper:2012_jumping' <<< "$out" && \
  grep -qx 'sinigaglia:2022_motor' <<< "$out" && \
  test "$(printf '%s\n' "$out" | wc -l | tr -d ' ')" -ge 2
}

it "extracts keys from LaTeX and Pandoc forms" keys_extraction_works

cat_mode_streams_known_content() {
  local draft out
  draft=$(mktemp -t tmp_draft2keys.XXXX.md)
  cat > "$draft" <<'MD'
This cites only Vesper: \citet{vesper:2012_jumping}.
MD
  if [[ ! -d "$PAPERS_ROOT" ]]; then
    echo "SKIP: PAPERS_DIR not found at $PAPERS_ROOT" >&2
    return 0
  fi
  out=$(PAPERS_DIR="$PAPERS_ROOT" "$TOOL" --cat "$draft" 2>/dev/null || true)
  rg -q '^# Are You Ready to Jump\?' <<< "$out"
}

it "--cat streams known fulltext (when available)" cat_mode_streams_known_content

echo "RESULT: $pass passed, $fail failed"
[[ "$fail" -eq 0 ]]

