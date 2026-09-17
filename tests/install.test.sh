#!/usr/bin/env bash
set -euo pipefail

# Installer regression tests. These use tiny fake repositories and package
# installers so the real user environment is never modified.

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)
cd "$REPO_ROOT"

source "$REPO_ROOT/tests/lib/test_helpers.sh"
test_suite "$0"

require_command rg

_make_fake_repo() {
  local root="$1"
  mkdir -p "$root/python"
  cp "$REPO_ROOT/install.sh" "$root/install.sh"
  chmod +x "$root/install.sh"

  cat > "$root/dummy-tool" <<'SH'
#!/usr/bin/env bash
exit 0
SH
  chmod +x "$root/dummy-tool"

  cat > "$root/run-tests.sh" <<'SH'
#!/usr/bin/env bash
exit 0
SH
  chmod +x "$root/run-tests.sh"
}

_uv_installs_when_pip_is_unavailable() {
  local tmpdir="$1"
  local fake_home="$tmpdir/home"
  local fake_bin="$tmpdir/fake-bin"
  local fake_repo="$tmpdir/repo"
  local uv_log="$tmpdir/uv.log"
  local python_log="$tmpdir/python.log"
  mkdir -p "$fake_home/.local/bin" "$fake_bin"
  _make_fake_repo "$fake_repo"

  cat > "$fake_bin/python3" <<'SH'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$PYTHON_LOG"
exit 97
SH
  chmod +x "$fake_bin/python3"

  cat > "$fake_bin/uv" <<'SH'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$UV_LOG"
target=""
python=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --target)
      shift
      target="$1"
      ;;
    --python)
      shift
      python="$1"
      ;;
  esac
  shift
done
[[ -n "$target" && -n "$python" ]] || exit 2
mkdir -p "$target/agent_tools"
printf '%s\n' '# fake runtime' > "$target/agent_tools/__init__.py"
SH
  chmod +x "$fake_bin/uv"

  : > "$uv_log"
  : > "$python_log"
  HOME="$fake_home" UV_LOG="$uv_log" PYTHON_LOG="$python_log" \
    PATH="$fake_bin:$PATH" "$fake_repo/install.sh"

  if [[ -s "$python_log" ]]; then
    echo "python3 was invoked even though uv was available" >&2
    cat "$python_log" >&2
    return 1
  fi
  rg -q -- '^pip install --quiet --python .*/fake-bin/python3 --target ' "$uv_log"
  [[ -d "$fake_home/.local/bin/.agent-tools-python/agent_tools" ]]
  [[ -x "$fake_home/.local/bin/dummy-tool" ]]
}
it_in_tmpdir "uses uv without requiring python3 pip" _uv_installs_when_pip_is_unavailable

_pip_fallback_still_works() {
  local tmpdir="$1"
  local fake_home="$tmpdir/home"
  local fake_bin="$tmpdir/fake-bin"
  local fake_repo="$tmpdir/repo"
  local python_log="$tmpdir/python.log"
  mkdir -p "$fake_home/.local/bin" "$fake_bin"
  _make_fake_repo "$fake_repo"

  cat > "$fake_bin/python3" <<'SH'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$PYTHON_LOG"
if [[ "$*" == "-m pip --version" ]]; then
  exit 0
fi
if [[ "$1" == "-m" && "$2" == "pip" && "$3" == "install" ]]; then
  shift 3
  target=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --target)
        shift
        target="$1"
        ;;
    esac
    shift
  done
  [[ -n "$target" ]] || exit 2
  mkdir -p "$target/agent_tools"
  printf '%s\n' '# fake runtime' > "$target/agent_tools/__init__.py"
  exit 0
fi
exit 2
SH
  chmod +x "$fake_bin/python3"

  : > "$python_log"
  HOME="$fake_home" PYTHON_LOG="$python_log" \
    PATH="$fake_bin:/usr/bin:/bin" "$fake_repo/install.sh"

  rg -q -- '^-m pip --version$' "$python_log"
  rg -q -- '^-m pip install --quiet --target ' "$python_log"
  [[ -d "$fake_home/.local/bin/.agent-tools-python/agent_tools" ]]
  [[ -x "$fake_home/.local/bin/dummy-tool" ]]
}
it_in_tmpdir "falls back to python3 pip when uv is unavailable" _pip_fallback_still_works

complete_suite
