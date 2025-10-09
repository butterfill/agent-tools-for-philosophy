#!/usr/bin/env bash
set -euo pipefail

# Tests for cite2pdf human-only tool

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)
cd "$REPO_ROOT"

TOOL="$REPO_ROOT/cite2pdf"

pass=0
fail=0

require() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "SKIP: missing dependency: $cmd" >&2
    exit 2
  fi
}

require fd

declare -a TMP_DIRS=()
declare -a TMP_FILES=()

cleanup() {
  for f in ${TMP_FILES[@]:-}; do
    [[ -f "$f" ]] && rm -f "$f"
  done
  for d in ${TMP_DIRS[@]:-}; do
    [[ -d "$d" ]] && rm -rf "$d"
  done
}
trap cleanup EXIT

make_tmpdir() {
  local dir
  dir=$(mktemp -d)
  TMP_DIRS+=("$dir")
  printf '%s\n' "$dir"
}

make_tmpfile() {
  local file
  file=$(mktemp)
  TMP_FILES+=("$file")
  printf '%s\n' "$file"
}

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

direct_match_resolves_pdf() {
  local papers pdf out rc
  papers=$(make_tmpdir)
  mkdir -p "$papers/sub"
  pdf="$papers/sub/vesper2012_jumping.pdf"
  : > "$pdf"
  set +e
  out=$(PAPERS_DIR="$papers" "$TOOL" "vesper:2012_jumping")
  rc=$?
  set -e
  [[ $rc -eq 0 ]] && [[ "$out" -ef "$pdf" ]]
}

stdin_ignores_comments_and_blank_lines() {
  local papers pdf out rc
  papers=$(make_tmpdir)
  mkdir -p "$papers"
  pdf="$papers/borg2024_acting.pdf"
  : > "$pdf"
  set +e
  out=$(printf '\n# ignore me\n\\citet{borg:2024_acting}\n' | PAPERS_DIR="$papers" "$TOOL")
  rc=$?
  set -e
  [[ $rc -eq 0 ]] && [[ "$out" -ef "$pdf" ]]
}

fallback_uses_cite2md_when_fd_finds_nothing() {
  local papers stub_bin pdf md out rc
  papers=$(make_tmpdir)
  stub_bin=$(make_tmpdir)
  mkdir -p "$papers/notes"
  md="$papers/notes/vesper2012_jumping.md"
  pdf="$papers/notes/vesper2012_jumping.pdf"
  : > "$md"
  : > "$pdf"

  # Stub fd to force fallback path
  cat > "$stub_bin/fd" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
  chmod +x "$stub_bin/fd"

  # Stub cite2md to return the markdown file path
  cat > "$stub_bin/cite2md" <<'EOF'
#!/usr/bin/env bash
printf '%s/notes/vesper2012_jumping.md\n' "${PAPERS_DIR}"
exit 0
EOF
  chmod +x "$stub_bin/cite2md"

  set +e
  out=$(PATH="$stub_bin:$PATH" PAPERS_DIR="$papers" "$TOOL" "vesper:2012_jumping")
  rc=$?
  set -e
  [[ $rc -eq 0 ]] && [[ "$out" == "$pdf" ]]
}

open_flag_invokes_viewer_and_prints_path() {
  local papers pdf stub_bin log rc out
  papers=$(make_tmpdir)
  stub_bin=$(make_tmpdir)
  log=$(make_tmpfile)
  mkdir -p "$papers"
  pdf="$papers/vesper2012_jumping.pdf"
  : > "$pdf"

  # Provide real fd and cite2md via symlink
  ln -s "$(command -v fd)" "$stub_bin/fd"
  ln -s "$REPO_ROOT/cite2md" "$stub_bin/cite2md"

  cat > "$stub_bin/xdg-open" <<'EOF'
#!/usr/bin/env bash
if [[ -n "${CITE2PDF_XDG_OPEN_LOG:-}" ]]; then
  printf '%s\n' "$*" >> "$CITE2PDF_XDG_OPEN_LOG"
fi
exit 0
EOF
  chmod +x "$stub_bin/xdg-open"

  set +e
  out=$(PATH="$stub_bin:$PATH" CITE2PDF_XDG_OPEN_LOG="$log" PAPERS_DIR="$papers" "$TOOL" --open "vesper:2012_jumping")
  rc=$?
  set -e
  [[ $rc -eq 0 ]] && [[ "$out" -ef "$pdf" ]] && { last=$(tail -n1 "$log"); [[ "$last" -ef "$pdf" ]]; }
}

missing_key_reports_standard_message() {
  local papers stdout err rc expected
  papers=$(make_tmpdir)
  stdout=$(make_tmpfile)
  err=$(make_tmpfile)
  set +e
  PAPERS_DIR="$papers" "$TOOL" "missing:key" >"$stdout" 2>"$err"
  rc=$?
  set -e
  expected="MISSING cite2pdf: missing:key (normalized: missingkey) in $papers"
  [[ $rc -eq 1 ]] && [[ ! -s "$stdout" ]] && grep -Fq "$expected" "$err"
}

it "resolves PDFs via direct fd match" direct_match_resolves_pdf
it "handles stdin input with comments and blank lines" stdin_ignores_comments_and_blank_lines
it "falls back to cite2md when direct lookup fails" fallback_uses_cite2md_when_fd_finds_nothing
it "opens viewer when --open is set while printing the path" open_flag_invokes_viewer_and_prints_path
it "reports standardized missing message and exits with 1" missing_key_reports_standard_message

echo "RESULT: $pass passed, $fail failed"
[[ $fail -eq 0 ]]
