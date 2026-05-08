#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)
cd "$REPO_ROOT"

source "$REPO_ROOT/tests/lib/test_helpers.sh"
test_suite "$0"

TOOL="$REPO_ROOT/cite2md"
DRAFT2KEYS="$REPO_ROOT/draft2keys"

require_command fd jq rg

write_md_sources() {
  local papers="$1" key norm
  shift
  mkdir -p "$papers"
  for key in "$@"; do
    norm=${key//:/}
    printf '# %s\n' "$key" > "$papers/$norm.md"
  done
}

nonempty_line_count() {
  sed '/^$/d' | wc -l | tr -d ' '
}

multiple_cli_args_are_independent() {
  with_tmpdir _multiple_cli_args_are_independent
}

_multiple_cli_args_are_independent() {
  local tmpdir="$1" papers out rc
  papers="$tmpdir/papers"
  write_md_sources "$papers" alpha:2020_one beta:2021_two gamma:2022_three

  set +e
  out=$(cd "$tmpdir" && PAPERS_DIR="$papers" "$TOOL" alpha:2020_one beta:2021_two gamma:2022_three)
  rc=$?
  set -e

  [[ $rc -eq 0 ]] && [[ "$(printf '%s\n' "$out" | nonempty_line_count)" == 3 ]]
}

it "processes multiple CLI arguments independently" multiple_cli_args_are_independent

space_separated_stdin_splits_raw_keys() {
  with_tmpdir _space_separated_stdin_splits_raw_keys
}

_space_separated_stdin_splits_raw_keys() {
  local tmpdir="$1" papers out rc expected
  papers="$tmpdir/papers"
  write_md_sources "$papers" alpha:2020_one beta:2021_two
  expected=$(printf 'missing:one\nmissing:two\n')

  set +e
  out=$(cd "$tmpdir" && printf '%s\n' 'alpha:2020_one missing:one beta:2021_two missing:two' | PAPERS_DIR="$papers" "$TOOL" 2>"$tmpdir/err.txt")
  rc=$?
  set -e

  [[ $rc -eq 1 ]] && \
    [[ "$(printf '%s\n' "$out" | nonempty_line_count)" == 2 ]] && \
    [[ "$(<"$tmpdir/missing-fulltext.txt")" == "$expected" ]]
}

it "splits space-separated raw keys on stdin and logs misses individually" space_separated_stdin_splits_raw_keys

newline_separated_stdin_still_works() {
  with_tmpdir _newline_separated_stdin_still_works
}

_newline_separated_stdin_still_works() {
  local tmpdir="$1" papers out rc
  papers="$tmpdir/papers"
  write_md_sources "$papers" alpha:2020_one beta:2021_two

  set +e
  out=$(cd "$tmpdir" && printf '%s\n' alpha:2020_one beta:2021_two | PAPERS_DIR="$papers" "$TOOL")
  rc=$?
  set -e

  [[ $rc -eq 0 ]] && [[ "$(printf '%s\n' "$out" | nonempty_line_count)" == 2 ]]
}

it "preserves newline-separated stdin behavior" newline_separated_stdin_still_works

mixed_success_failure_exits_nonzero() {
  with_tmpdir _mixed_success_failure_exits_nonzero
}

_mixed_success_failure_exits_nonzero() {
  local tmpdir="$1" papers out rc
  papers="$tmpdir/papers"
  write_md_sources "$papers" alpha:2020_one beta:2021_two

  set +e
  out=$(cd "$tmpdir" && PAPERS_DIR="$papers" "$TOOL" alpha:2020_one missing:key beta:2021_two 2>"$tmpdir/err.txt")
  rc=$?
  set -e

  [[ $rc -eq 1 ]] && \
    [[ "$(printf '%s\n' "$out" | nonempty_line_count)" == 2 ]] && \
    [[ "$(<"$tmpdir/missing-fulltext.txt")" == "missing:key" ]]
}

it "emits resolved paths but exits nonzero when any key is missing" mixed_success_failure_exits_nonzero

latex_multiple_keys_are_split() {
  with_tmpdir _latex_multiple_keys_are_split
}

_latex_multiple_keys_are_split() {
  local tmpdir="$1" papers out rc
  papers="$tmpdir/papers"
  write_md_sources "$papers" alpha:2020_one beta:2021_two gamma:2022_three

  set +e
  out=$(cd "$tmpdir" && PAPERS_DIR="$papers" "$TOOL" '\citep{alpha:2020_one,beta:2021_two,gamma:2022_three}')
  rc=$?
  set -e

  [[ $rc -eq 0 ]] && [[ "$(printf '%s\n' "$out" | nonempty_line_count)" == 3 ]]
}

it "splits multiple keys inside LaTeX citation commands" latex_multiple_keys_are_split

latex_optional_text_is_not_tokenized() {
  with_tmpdir _latex_optional_text_is_not_tokenized
}

_latex_optional_text_is_not_tokenized() {
  local tmpdir="$1" papers out rc
  papers="$tmpdir/papers"
  write_md_sources "$papers" alpha:2020_one beta:2021_two

  set +e
  out=$(cd "$tmpdir" && PAPERS_DIR="$papers" "$TOOL" '\citep[see][ch. 2]{alpha:2020_one,beta:2021_two}' 2>"$tmpdir/err.txt")
  rc=$?
  set -e

  [[ $rc -eq 0 ]] && \
    [[ "$(printf '%s\n' "$out" | nonempty_line_count)" == 2 ]] && \
    [[ ! -e "$tmpdir/missing-fulltext.txt" ]]
}

it "keeps LaTeX optional text out of raw-key tokenization" latex_optional_text_is_not_tokenized

draft2keys_pipeline_and_collapsed_args_work() {
  with_tmpdir _draft2keys_pipeline_and_collapsed_args_work
}

_draft2keys_pipeline_and_collapsed_args_work() {
  local tmpdir="$1" papers draft piped collapsed keys
  papers="$tmpdir/papers"
  draft="$tmpdir/draft.md"
  write_md_sources "$papers" alpha:2020_one beta:2021_two
  printf 'Text \\citep{alpha:2020_one,beta:2021_two}.\n' > "$draft"

  piped=$("$DRAFT2KEYS" "$draft" | (cd "$tmpdir" && PAPERS_DIR="$papers" "$TOOL"))
  keys=$("$DRAFT2KEYS" "$draft")
  # shellcheck disable=SC2086
  collapsed=$(cd "$tmpdir" && PAPERS_DIR="$papers" "$TOOL" $keys)

  [[ "$(printf '%s\n' "$piped" | nonempty_line_count)" == 2 ]] && \
    [[ "$(printf '%s\n' "$collapsed" | nonempty_line_count)" == 2 ]]
}

it "accepts draft2keys output through pipes and collapsed command substitution" draft2keys_pipeline_and_collapsed_args_work

real_batch_shape_is_not_one_combined_key() {
  with_tmpdir _real_batch_shape_is_not_one_combined_key
}

_real_batch_shape_is_not_one_combined_key() {
  local tmpdir="$1" papers out rc
  local keys=(
    koleva:2012_tracing graham:2019_moral vanleeuwen:2012_regional
    iyer:2012_understanding graham:2009_liberals graham:2011_mapping
    haidt:2007_when graham:2013_chapter atari:2023_morality
    atari:2020_foundations meindl:2019_distributive atari:2022_pathogens
    haidt:2007_new lai:2014_moral schnall:2015_landy haidt:2008_moralitya
    haidt:2001_sexual haidt:2007_moral haidt:1993_affect haidt:2004_intuitive
    haidt:2008_social schnall:2008_disgust haidt:2001_emotional
    wheatley:2005_hypnotic haidt:2011_how rozin:2008_disgust
    haidt:2013_righteous
  )
  papers="$tmpdir/papers"
  write_md_sources "$papers" "${keys[@]}"

  set +e
  out=$(cd "$tmpdir" && PAPERS_DIR="$papers" "$TOOL" "${keys[@]}" 2>"$tmpdir/err.txt")
  rc=$?
  set -e

  [[ $rc -eq 0 ]] && \
    [[ "$(printf '%s\n' "$out" | nonempty_line_count)" == "${#keys[@]}" ]] && \
    [[ ! -e "$tmpdir/missing-fulltext.txt" ]]
}

it "handles the real multi-key batch shape as independent keys" real_batch_shape_is_not_one_combined_key

complete_suite
