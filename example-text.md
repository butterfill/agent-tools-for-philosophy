## cite2md
### current --help examples
No "Examples" section in current --help output.
### old --help examples
```text
Examples (list → then read one):
  # From a draft → keys → read first key
  draft2keys draft.md > keys.txt
  key=$(sed -n '1p' keys.txt)
  cite2md --cat "$key"
  
  # Path-only, then search in that file
  p=$(cite2md vesper:2012_jumping)
  rg -n "joint outcome" "$p"
```

## cite2pdf
### current --help examples
No "Examples" section in current --help output.
### old --help examples
Command not present in commit 5eefa390fd58f0419d436a0c324e04be7749b7ac.

## cite2bib
### current --help examples
No "Examples" section in current --help output.
### old --help examples
```text
Examples (list → then read one):
  find-bib --author vesper --year 2013 --title jump > keys.txt
  key=$(sed -n '1p' keys.txt)
  cite2bib "$key" | rg '^@'
  cite2bib vesper2012_jumping > vesper.bib
```

## draft2keys
### current --help examples
No "Examples" section in current --help output.
### old --help examples
```text
Suggested workflow:
  draft2keys draft.md > keys.txt
  key=$(sed -n '1p' keys.txt)
  cite2md --cat "$key"
```

## path2key
### current --help examples
No "Examples" section in current --help output.
### old --help examples
No "Examples" section in commit 5eefa390fd58f0419d436a0c324e04be7749b7ac.

## find-bib
### current --help examples
No "Examples" section in current --help output.
### old --help examples
```text
Suggested workflow (list → then read one):
  find-bib --author vesper --year 2013 --title jump > keys.txt
  key=$(sed -n '1p' keys.txt)
  cite2bib "$key"
  # Or: p=$(cite2md "$key")
```

## rg-sources
### current --help examples
No "Examples" section in current --help output.
### old --help examples
```text
Examples (list → then read one):
  rg-sources -n "bayesian prior"
  rg-sources -i -C1 "causal"
  rg-sources -l -i "causal effect" > hits.txt
  p=$(sed -n '1p' hits.txt); cat-sources "$p"
  Note: file types are fixed to Markdown; type/glob overrides are not supported here. Use `rg-sources -l ... | cat-sources` to stream content.
```

## fd-sources
### current --help examples
No "Examples" section in current --help output.
### old --help examples
```text
Examples (list → then read one):
  fd-sources vesper2012_jumping
  fd-sources -i 'vesper.*jump'
  fd-sources -i 'butterfill.*2019'
  p=$(fd-sources vesper2012_jumping | sed -n '1p'); cat-sources "$p"
```

## cat-sources
### current --help examples
No "Examples" section in current --help output.
### old --help examples
```text
Examples (list → then read one):
  p=$(fd-sources vesper2012_jumping | sed -n '1p'); cat-sources "$p"
  p=$(rg-sources -l 'bayesian prior' | sed -n '1p'); cat-sources "$p"
  cite2md --cat vesper:2012_jumping
```
