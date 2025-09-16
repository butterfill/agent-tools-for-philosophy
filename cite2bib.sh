#!/usr/bin/env bash
set -euo pipefail

# Resolve a LaTeX citation or BibTeX key to its BibTeX entry
# See --help for detailed usage.

BIB_FILE=${BIB_FILE:-"$HOME/endnote/phd_biblio.bib"}

print_help() {
  cat <<'EOF'
cite2bib.sh — resolve citation/key to BibTeX entry (from ~/endnote/phd_biblio.bib)

Usage:
  ./cite2bib.sh <citation-or-key>

Inputs accepted:
  - LaTeX-style citation, e.g. "\citet{vesper:2012_jumping}"
  - BibTeX key with colons, e.g. vesper:2012_jumping
  - Normalized key (colons removed), e.g. vesper2012_jumping

Output:
  - Prints the full BibTeX entry to stdout. No extra logging on success.

Resolution strategy:
  - Exact key match first: lines like ^@type{<key>,
  - Fallback: normalize colons out of keys and match against normalized entry keys

Environment:
  - BIB_FILE: override BibTeX path (default: $HOME/endnote/phd_biblio.bib)

Exit codes:
  - 0: success (entry printed)
  - 1: not found / BIB_FILE missing
  - 2: usage error / missing input

Dependencies:
  - ripgrep (rg), awk, sed

Examples:
  ./cite2bib.sh "\citet{vesper:2012_jumping}" | rg '^@'
  ./cite2bib.sh vesper2012_jumping > vesper.bib
  ./cite2bib.sh alter:2009_uniting | rg doi
EOF
}

if [ $# -lt 1 ]; then
  print_help >&2
  exit 2
fi

if [[ "$1" == "-h" || "$1" == "--help" ]]; then
  print_help
  exit 0
fi

input="$1"

# Extract bibkey if LaTeX citation; otherwise use input as key
if [[ "$input" =~ \{[^}]+\} ]]; then
  bibkey=$(printf '%s\n' "$input" | sed -n 's/.*{\([^}]*\)}.*/\1/p')
else
  bibkey="$input"
fi

if [ -z "$bibkey" ]; then
  echo "Could not parse a key from input: $input" >&2
  exit 2
fi

normkey=$(printf '%s' "$bibkey" | tr -d ':')

if [ ! -f "$BIB_FILE" ]; then
  echo "BibTeX file not found: $BIB_FILE" >&2
  exit 1
fi

# Function: print the entry starting at a line number
extract_from_line() {
  local start_line="$1"
  awk -v start="$start_line" 'NR<start{next} { if (!started) started=1; line=$0; opens=gsub(/\{/ ,"{", line); closes=gsub(/\}/ ,"}", line); depth+=opens-closes; print; if (started && depth<=0) exit }' "$BIB_FILE"
}

# Try exact key match first
start_line=$(rg -n "^\s*@\w+\{${bibkey}," "$BIB_FILE" | head -n1 | cut -d: -f1 || true)

if [ -n "${start_line:-}" ]; then
  extract_from_line "$start_line"
  exit 0
fi

# Fallback: match on normalized key (colons removed)
# Scan for entry starts and compare normalized keys
start_line=$(awk -v nk="$normkey" '
  match($0, /^\s*@[A-Za-z]+\{([^,]+),/, m) {
    key=m[1]; gsub(":","",key);
    if (key==nk) { print NR; exit }
  }' "$BIB_FILE")

if [ -n "${start_line:-}" ]; then
  extract_from_line "$start_line"
  exit 0
fi

echo "BibTeX entry not found for key: $bibkey (normalized: $normkey)" >&2
exit 1
