#!/usr/bin/env bash
set -euo pipefail

# install.sh — install agent-tools into a user-accessible bin directory
# Preference order:
#   1) $HOME/syncthing/bin (if exists)
#   2) $HOME/.local/bin (create if missing)
#   3) $HOME/bin (create if missing)
#   4) First writable directory already in $PATH

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

choose_target_dir() {
  local path_dirs IFS=':'
  local d

  # 1) syncthing/bin override
  if [[ -d "$HOME/syncthing/bin" ]]; then
    printf '%s\n' "$HOME/syncthing/bin"
    return 0
  fi

  # 2) ~/.local/bin (create if needed)
  if [[ -d "$HOME/.local/bin" ]] || mkdir -p "$HOME/.local/bin" 2>/dev/null; then
    if [[ -w "$HOME/.local/bin" ]]; then
      printf '%s\n' "$HOME/.local/bin"
      return 0
    fi
  fi

  # 3) ~/bin (create if needed)
  if [[ -d "$HOME/bin" ]] || mkdir -p "$HOME/bin" 2>/dev/null; then
    if [[ -w "$HOME/bin" ]]; then
      printf '%s\n' "$HOME/bin"
      return 0
    fi
  fi

  # 4) first writable directory already in PATH
  IFS=':' read -r -a path_dirs <<< "${PATH:-}"
  for d in "${path_dirs[@]}"; do
    # skip empty elements
    [[ -z "$d" ]] && continue
    if [[ -d "$d" && -w "$d" ]]; then
      printf '%s\n' "$d"
      return 0
    fi
  done

  return 1
}

TARGET_DIR=$(choose_target_dir || true)
if [[ -z "${TARGET_DIR:-}" ]]; then
  echo "install.sh: could not find a writable bin directory. Set PATH or create ~/.local/bin." >&2
  exit 2
fi

echo "Installing tools to: $TARGET_DIR"

installed=()
skipped=()

shopt -s nullglob
for f in "$SCRIPT_DIR"/*; do
  base=$(basename "$f")
  # skip non-regular files and non-executables
  if [[ ! -f "$f" || ! -x "$f" ]]; then
    continue
  fi
  # do not install the installer itself
  if [[ "$base" == "install.sh" ]]; then
    continue
  fi
  # copy tool
  cp -f "$f" "$TARGET_DIR/$base"
  chmod +x "$TARGET_DIR/$base" || true
  installed+=("$base")
done
shopt -u nullglob

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

