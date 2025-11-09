#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)
cd "$REPO_ROOT"

source "$REPO_ROOT/tests/lib/test_helpers.sh"
test_suite "$0"

TOOL="$REPO_ROOT/draft2keys"

require_command rg

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

fixture_bugs_is_handled() {
  local out expected
  out=$("$TOOL" tests/fixtures/draft2keys-bugs.md)
  expected=$(cat <<'EOF'
steward:2009_animal
doggett:2012_questions
smith:2012_friends
pandoc:key1
pandoc:key2
EOF
)
  if [[ "$out" != "$expected" ]]; then
    echo "Unexpected output:" >&2
    printf '%s\n' "$out" >&2
    return 1
  fi
}

it "handles tricky LaTeX and Pandoc cases from fixture without false positives" fixture_bugs_is_handled

complete_suite
