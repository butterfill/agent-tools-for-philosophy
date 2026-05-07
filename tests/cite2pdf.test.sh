#!/usr/bin/env bash
set -euo pipefail

# Tests for cite2pdf human-only tool

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)
cd "$REPO_ROOT"

source "$REPO_ROOT/tests/lib/test_helpers.sh"
test_suite "$0"

TOOL="$REPO_ROOT/cite2pdf"

require_command fd

direct_match_resolves_pdf() {
  with_tmpdir _direct_match_resolves_pdf
}

_direct_match_resolves_pdf() {
  local tmpdir="$1"
  local papers pdf out rc
  papers="$tmpdir/papers"
  mkdir -p "$papers/sub"
  pdf="$papers/sub/vesper2012_jumping.pdf"
  : > "$pdf"
  set +e
  out=$(PAPERS_DIR="$papers" "$TOOL" "vesper:2012_jumping")
  rc=$?
  set -e
  [[ $rc -eq 0 ]] && [[ "$out" -ef "$pdf" ]]
}

direct_match_ignores_fd_options() {
  with_tmpdir _direct_match_ignores_fd_options
}

_direct_match_ignores_fd_options() {
  local tmpdir="$1"
  local papers pdf out rc
  papers="$tmpdir/papers"
  mkdir -p "$papers/sub"
  pdf="$papers/sub/vesper2012_jumping.pdf"
  : > "$pdf"
  set +e
  out=$(FD_OPTIONS='--glob *definitely_no_fd_hits*' PAPERS_DIR="$papers" "$TOOL" "vesper:2012_jumping")
  rc=$?
  set -e
  [[ $rc -eq 0 ]] && [[ "$out" -ef "$pdf" ]]
}

stdin_ignores_comments_and_blank_lines() {
  with_tmpdir _stdin_ignores_comments_and_blank_lines
}

_stdin_ignores_comments_and_blank_lines() {
  local tmpdir="$1"
  local papers pdf out rc
  papers="$tmpdir/papers"
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
  with_tmpdir _fallback_uses_cite2md_when_fd_finds_nothing
}

_fallback_uses_cite2md_when_fd_finds_nothing() {
  local tmpdir="$1"
  local papers stub_bin pdf md out rc
  papers="$tmpdir/papers"
  stub_bin="$tmpdir/bin"
  mkdir -p "$papers/notes"
  mkdir -p "$stub_bin"
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
  with_tmpdir _open_flag_invokes_viewer_and_prints_path
}

_open_flag_invokes_viewer_and_prints_path() {
  local tmpdir="$1"
  local papers pdf stub_bin log rc out
  papers="$tmpdir/papers"
  stub_bin="$tmpdir/bin"
  log="$tmpdir/xdg-open.log"
  mkdir -p "$papers"
  mkdir -p "$stub_bin"
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

_missing_key_reports_standard_message() {
  local tmpdir="$1"
  local papers stdout err rc expected
  papers="$tmpdir/papers"
  stdout="$tmpdir/stdout.txt"
  err="$tmpdir/err.txt"
  mkdir -p "$papers"
  set +e
  PAPERS_DIR="$papers" "$TOOL" "missing:key" >"$stdout" 2>"$err"
  rc=$?
  set -e
  expected="MISSING cite2pdf: missing:key (normalized: missingkey) in $papers"
  [[ $rc -eq 1 ]] && [[ ! -s "$stdout" ]] && grep -Fq "$expected" "$err"
}

it "resolves PDFs via direct fd match" direct_match_resolves_pdf
it "ignores FD_OPTIONS during direct fd lookup" direct_match_ignores_fd_options
it "handles stdin input with comments and blank lines" stdin_ignores_comments_and_blank_lines
it "falls back to cite2md when direct lookup fails" fallback_uses_cite2md_when_fd_finds_nothing
it "opens viewer when --open is set while printing the path" open_flag_invokes_viewer_and_prints_path
it_in_tmpdir "reports standardized missing message and exits with 1" _missing_key_reports_standard_message

complete_suite
