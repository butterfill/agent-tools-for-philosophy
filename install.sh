#!/usr/bin/env bash
set -euo pipefail

# install.sh — install agent-tools into a user-accessible bin directory
# Preference order:
#   1) $HOME/syncthing/bin (if exists)
#   2) $HOME/.local/bin (must already exist)
#   3) $HOME/bin (must already exist)

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

choose_target_dir() {
  # 1) syncthing/bin override
  if [[ -d "$HOME/syncthing/bin" ]]; then
    printf '%s\n' "$HOME/syncthing/bin"
    return 0
  fi

  # 2) ~/.local/bin (must already exist)
  if [[ -d "$HOME/.local/bin" && -w "$HOME/.local/bin" ]]; then
    printf '%s\n' "$HOME/.local/bin"
    return 0
  fi

  # 3) ~/bin (must already exist)
  if [[ -d "$HOME/bin" && -w "$HOME/bin" ]]; then
    printf '%s\n' "$HOME/bin"
    return 0
  fi

  return 1
}

TARGET_DIR=$(choose_target_dir || true)
if [[ -z "${TARGET_DIR:-}" ]]; then
  echo "install.sh: no install directory found. Create one of: $HOME/syncthing/bin, $HOME/.local/bin, or $HOME/bin and re-run." >&2
  exit 2
fi

echo "Installing tools to: $TARGET_DIR"

command -v python3 >/dev/null 2>&1 || {
  echo "install.sh: python3 is required for the canonical ReferenceCatalog runtime used by find-bib" >&2
  exit 2
}
PYTHON_BIN=$(command -v python3)

if command -v uv >/dev/null 2>&1; then
  PYTHON_INSTALLER=uv
elif "$PYTHON_BIN" -m pip --version >/dev/null 2>&1; then
  PYTHON_INSTALLER=pip
else
  echo "install.sh: uv or python3 pip is required to install the canonical ReferenceCatalog runtime used by find-bib" >&2
  exit 2
fi

PYTHON_RUNTIME_DIR="$TARGET_DIR/.agent-tools-python"
PYTHON_RUNTIME_TMP=$(mktemp -d "$TARGET_DIR/.agent-tools-python.tmp.XXXXXX")
cleanup_runtime_tmp() {
  rm -rf "$PYTHON_RUNTIME_TMP"
}
trap cleanup_runtime_tmp EXIT

if [[ "$PYTHON_INSTALLER" == "uv" ]]; then
  # Bind uv to the same python3 that will execute find-bib so compiled wheels
  # (for example rapidfuzz) match the runtime interpreter.
  uv pip install --quiet --python "$PYTHON_BIN" --target "$PYTHON_RUNTIME_TMP" "$SCRIPT_DIR/python"
else
  PIP_DISABLE_PIP_VERSION_CHECK=1 "$PYTHON_BIN" -m pip install --quiet --target "$PYTHON_RUNTIME_TMP" "$SCRIPT_DIR/python"
fi
rm -rf "$PYTHON_RUNTIME_DIR"
mv "$PYTHON_RUNTIME_TMP" "$PYTHON_RUNTIME_DIR"
trap - EXIT

echo "Installed canonical ReferenceCatalog runtime to: $PYTHON_RUNTIME_DIR"

installed=()

shopt -s nullglob
for f in "$SCRIPT_DIR"/*; do
  base=$(basename "$f")
  # skip non-regular files and non-executables
  if [[ ! -f "$f" || ! -x "$f" ]]; then
    continue
  fi
  # do not install the installer itself or the test runner
  if [[ "$base" == "install.sh" || "$base" == "run-tests.sh" ]]; then
    continue
  fi
  # copy tool
  cp -f "$f" "$TARGET_DIR/$base"
  chmod +x "$TARGET_DIR/$base" || true
  installed+=("$base")
done
shopt -u nullglob

if [[ -d "$SCRIPT_DIR/help-text" ]]; then
  mkdir -p "$TARGET_DIR/help-text"
  cp -a "$SCRIPT_DIR/help-text/." "$TARGET_DIR/help-text/"
fi

if [[ ${#installed[@]} -eq 0 ]]; then
  echo "install.sh: no executable tools found to install in $SCRIPT_DIR" >&2
  exit 1
fi

echo "Installed ${#installed[@]} tool(s): ${installed[*]}"

# Hint if target dir is not on PATH
case ":${PATH}:" in
  *:"${TARGET_DIR}":*) ;; # already present
  *) echo "Note: $TARGET_DIR is not on PATH; add it to your shell profile." ;;
esac

# Run test suite after installation
if [[ -x "$SCRIPT_DIR/run-tests.sh" ]]; then
  echo "Running test suite..."
  # Prepend install dir to PATH so tests that rely on installed names work.
  # Expose the installed Python runtime so the repository copy of find-bib can
  # exercise the same canonical ReferenceCatalog implementation during tests.
  PATH="$TARGET_DIR:$PATH" \
    PYTHONPATH="$PYTHON_RUNTIME_DIR${PYTHONPATH:+:$PYTHONPATH}" \
    "$SCRIPT_DIR/run-tests.sh"
fi
