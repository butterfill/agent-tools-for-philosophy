#!/usr/bin/env python3
"""
copy_tex_sources.py — Copy .tex sources listed in tex-index-of-publications.jsonl
into data/tex-sources/, renaming by BibTeX key (with ':' removed).

Behavior
- Reads JSONL from data/tex-index-of-publications/tex-index-of-publications.jsonl
  Each line must be a JSON object with fields:
    {"key": "butterfill:2015_gilbert", "filenames": ["~/path/to/file.tex", ...]}
- For each .tex file in "filenames":
  - Expands "~" to the user's home.
  - Unescapes common shell escapes (e.g., "\ ", "\(", "\)").
  - Copies the file to data/tex-sources/.
  - Destination filename is the BibTeX key with ':' removed.
    - If there are multiple .tex files for the same key, numeric suffixes are added: _2, _3, ...
  - Keeps the .tex extension.
- Skips entries where the source file does not exist, printing a warning to stderr.

Notes
- This script is intended to be run on the machine where the source files exist.
- No network access is used; only local filesystem paths are referenced.

Usage
  python3 data/copy_tex_sources.py

Exit codes
  0 on success; 1 on error reading the index file.
"""
from __future__ import annotations

import json
import os
import re
import shutil
import sys
from pathlib import Path
from typing import Iterable, List, Tuple


def unescape_shell_escapes(path: str) -> str:
    """Remove backslash escapes before common shell-special characters.

    This turns sequences like "\ " and "\(" into literal space and '(' respectively.
    It leaves other backslashes intact.
    """
    # Characters commonly escaped in shell paths; include space explicitly
    special = r" ()\[\]{}&|;'\"<>?*"
    return re.sub(r"\\([" + special + "])", r"\1", path)


def unique_dest_path(dest_dir: Path, desired_name: str) -> Path:
    """Return a non-colliding destination path under dest_dir for desired_name.

    If desired_name does not exist, return it. Otherwise append _2, _3, ... before extension.
    """
    base = dest_dir / desired_name
    if not base.exists():
        return base

    stem = base.stem
    suffix = base.suffix
    i = 2
    while True:
        candidate = dest_dir / f"{stem}_{i}{suffix}"
        if not candidate.exists():
            return candidate
        i += 1


def load_jsonl(path: Path) -> Iterable[Tuple[str, List[str]]]:
    """Yield (key, filenames) pairs from a JSONL file.

    Skips blank lines and lines starting with '#'.
    """
    with path.open("r", encoding="utf-8") as f:
        for lineno, line in enumerate(f, start=1):
            s = line.strip()
            if not s or s.startswith("#"):
                continue
            try:
                obj = json.loads(s)
            except json.JSONDecodeError as e:
                print(f"ERROR: {path}:{lineno}: invalid JSON: {e}", file=sys.stderr)
                continue
            key = obj.get("key")
            filenames = obj.get("filenames")
            if not key or not isinstance(key, str):
                print(f"WARNING: {path}:{lineno}: missing or invalid 'key'", file=sys.stderr)
                continue
            if not isinstance(filenames, list):
                print(f"WARNING: {path}:{lineno}: missing or invalid 'filenames' list", file=sys.stderr)
                continue
            yield key, [str(p) for p in filenames]


def main() -> int:
    script_dir = Path(__file__).resolve().parent
    idx_path = script_dir / "tex-index-of-publications" / "tex-index-of-publications.jsonl"
    dest_dir = script_dir / "tex-sources"

    if not idx_path.exists():
        print(f"ERROR: index not found: {idx_path}", file=sys.stderr)
        return 1

    dest_dir.mkdir(parents=True, exist_ok=True)

    total_entries = 0
    total_sources = 0
    copied = 0
    missing = 0
    skipped_non_tex = 0

    for key, sources in load_jsonl(idx_path):
        total_entries += 1
        key_basename = key.replace(":", "")

        # Count .tex sources only, but preserve original order
        tex_sources = [s for s in sources if str(s).lower().endswith(".tex")]
        skipped_non_tex += len(sources) - len(tex_sources)

        for i, src in enumerate(tex_sources, start=1):
            total_sources += 1
            # Normalize path
            src_norm = unescape_shell_escapes(os.path.expanduser(src))

            if not os.path.exists(src_norm):
                print(f"WARN: missing source for {key}: {src_norm}", file=sys.stderr)
                missing += 1
                continue

            # Determine destination name
            if len(tex_sources) == 1:
                desired_name = f"{key_basename}.tex"
            else:
                desired_name = f"{key_basename}_{i}.tex"

            dest_path = unique_dest_path(dest_dir, desired_name)

            # Copy
            shutil.copy2(src_norm, dest_path)
            copied += 1
            print(f"Copied: {src_norm} -> {dest_path}")

    # Summary
    print(
        (
            f"Processed {total_entries} entries; considered {total_sources} .tex sources; "
            f"copied {copied}; missing {missing}; skipped non-.tex paths {skipped_non_tex}."
        ),
        file=sys.stderr,
    )

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
