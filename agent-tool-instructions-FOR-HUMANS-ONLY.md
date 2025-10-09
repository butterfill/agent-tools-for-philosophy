## Human-Only Features
Some of the features are for humans only, and are not intended to be used by AI agents. These features are not mentioned in the `--help` output of the command line tools
(unless the entire tool is human-only).

## cite2md
- `--vs` : open in vs code (same as `code "$(cite2md [key])"`)
- `---vsi` : open in vs code insiders (same as `code-insiders "$(cite2md [key])"`)
- `-r` / `--reveal` : open Finder with the file revealed (same as `open -R "$(cite2md [key])"`)


# cite2pdf (human-only tool)
This works as cite2md but returns a PDF path if available.
There is no `--cat` option, as PDFs cannot be printed to stdout usefully.
There is an `-o` / `--open` option to open the PDF in the default viewer.

## Resolution Strategy
1) Parse key and derive `normkey` (remove `:` from key).
2) Direct filename lookup using `fd` under `$PAPERS_DIR`:
   - Regex: `${normkey}\.pdf$`; take the first match.
3) Fallback to execting `cite2md` and, if this yields a result, replacing `.md` with `.pdf` if that file exists.
4) If no file is found, exit non‑zero with a concise error including both forms of the key.

