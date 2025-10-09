## Human-Only Features
Some of the features are for humans only, and are not intended to be used by AI agents. These features are not mentioned in the `--help` output of the command line tools
(unless the entire tool is human-only).

## cite2md
- `--vs`: open in VS Code (same as `code "$(cite2md [key])"`)
- `--vsi`: open in VS Code Insiders (same as `code-insiders "$(cite2md [key])"`)
- `-r` / `--reveal`: open Finder with the file revealed (same as `open -R "$(cite2md [key])"`)

## cite2pdf (human-only tool)
- Reads LaTeX citations (`\citet{...}`), colon keys, or normalized keys.
- Resolves PDFs under `$PAPERS_DIR` (default `~/papers`); prints absolute path.
- `-o` / `--open`: launch default viewer (`xdg-open`, `open`, or `start`) after printing the path.
- `-r` / `--reveal`: reveal the file (macOS `open -R`, otherwise open the directory).
- Blank lines and lines starting with `#` are ignored when reading from stdin.
- Resolution steps: (1) `fd --regex "${normkey}\.pdf$"`; (2) `cite2md` fallback with `.md → .pdf`.
