#!/usr/bin/env bash
set -euo pipefail

# Tests for path2key
#
# Assumptions:
# - $PAPERS_DIR exists and remains stable (default: $HOME/papers)
# - $BIB_FILE exists and contains entries for the sample keys used below
# - cite2bib is installed and on PATH
# - jq is installed (for index fallback test)

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)
cd "$REPO_ROOT"

source "$REPO_ROOT/tests/lib/test_helpers.sh"
test_suite "$0"

TOOL="$REPO_ROOT/path2key"
export TOOL
# Ensure local tools are discoverable (cite2bib)
export PATH="$REPO_ROOT:$PATH"

require_command cite2bib awk sed rg jq

# Prepare a temporary BibTeX file so cite2bib can validate keys
TMP_BIB=$(mktemp -t tmp_rovodev_path2key_bib.XXXX.bib)
TMP_IDX=$(mktemp -t tmp_rovodev_path2key_index.XXXX.jsonl)
export TMP_IDX
trap 'rm -f "$TMP_BIB" "$TMP_IDX"' EXIT
cat > "$TMP_BIB" <<'BIB'
@article{sinigaglia:2022_motor,
  title={Motor representation in joint action},
  author={Sinigaglia, Corrado and Butterfill, Stephen},
  year={2022}
}
@article{vesper:2012_jumping,
  title={Jumping together},
  author={Vesper, Christina and Sebanz, Natalie and Knoblich, Günther},
  year={2012}
}
@inproceedings{Butterfill:2012fk,
  title={Some legacy key},
  author={Butterfill, Stephen},
  year={2012}
}
BIB
export BIB_FILE="$TMP_BIB"

# Helpers
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
  echo "$out" | rg -q "$pattern"
}

# --- Tests ---

# 1) Filename heuristic — simple normalized key in basename
it "resolves sinigaglia:2022_motor from basename" \
  has_line_matching '^sinigaglia:2022_motor$' \
  "$TOOL" "sinigaglia2022_motor.md"

# 2) Filename heuristic — last word after spaces in filename
it "resolves vesper:2012_jumping from a filename with spaces" \
  has_line_matching '^vesper:2012_jumping$' \
  "$TOOL" "some notes vesper2012_jumping.md"

# 2b) Filename heuristic — complex prefix with escaped dot (macOS portability)
it "resolves vesper:2012_jumping from a complex prefix with escaped dot" \
  has_line_matching '^vesper:2012_jumping$' \
  "$TOOL" "Vesper et al\\. - 2012 - Are You Ready to Jump Predictive Mechanisms vesper2012_jumping.md"

# 3) Legacy mixed-case key with letters after year
it "resolves Butterfill:2012fk from mixed-case legacy form" \
  has_line_matching '^Butterfill:2012fk$' \
  "$TOOL" "Butterfill2012fk.md"

# 4) Index fallback — use a temporary index mapping a non-heurstic basename to a known key
it "resolves via index fallback when heuristic doesn't match" bash -lc '
  printf %s "{\"key\": \"sinigaglia:2022_motor\", \"filename\": \"random-nonheuristic-name.md\"}\n" > "$TMP_IDX"
  out=$(INDEX_FILE="$TMP_IDX" "$TOOL" "random-nonheuristic-name.md" 2>/dev/null || true)
  echo "$out"
  [[ "$out" == "sinigaglia:2022_motor" ]]
'

complete_suite
