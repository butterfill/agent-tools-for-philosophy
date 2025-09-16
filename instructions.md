## Finding the fulltext of a cited source
You should be able to execute the following shell commands:
  - cite2md.sh - resolve citation/key to Markdown fulltext path
  - cite2bib.sh - resolve citation/key to BibTeX entry

The tools are on your PATH, so no `./` prefix is needed.

**Usage examples:**
- `cite2md.sh -c "\citet{vesper:2012_jumping}"` — get full text from LaTeX citation
- `cite2md.sh "vesper:2012_jumping"` — get full text from BibTeX key
- `cite2bib.sh "\citet{vesper:2012_jumping}"` — get BibTeX entry from LaTeX citation  
- `cite2bib.sh "vesper:2012_jumping"` — get BibTeX entry from BibTeX key

**Note:** The tools accept either LaTeX-style citations (with `\citet{}`) or bare BibTeX keys. 

Please check you can execute the shell commands `cite2md.sh` and `cite2bib.sh` to obtain info for the key `vesper:2012_jumping`.  Use their `--help` as needed.  **If you cannot execute these commands, stop immediately and report the error.**
