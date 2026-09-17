# find-bib — Filter the canonical reference catalogue

`find-bib` is a small, agent-friendly CLI for locating bibliography records with explicit field filters and printing their citation keys or BibTeX artifacts.

It is a consumer of the shared Python `agent_tools.ReferenceCatalog`. It must not independently read, parse, de-duplicate, or choose between `BIB_JSON` and `ZOTERO_JSON`.

## Name & Purpose

- Command: `find-bib`
- Goal: filter the **complete canonical catalogue** by author/year/DOI/title/abstract substrings.
- Default output: canonical citation keys, one per line.
- `--cat`: resolve each matching key through `cite2bib` and emit BibTeX.

`find-bib` is deliberately a field-filter surface, not a second fuzzy ranker. Fuzzy ranking belongs to `ReferenceCatalog.search()` consumers such as bibq/research-mcp.

## Canonical catalogue contract

Source membership, identity, precedence, and loading semantics come from `ReferenceCatalog`:

- `BIB_JSON` is the required primary/cited source (default `$HOME/endnote/phd_biblio.json`).
- `ZOTERO_JSON` is the optional complete-library source (default `$HOME/endnote/zotero-export.json`).
- `find-bib` filters the full canonical union (`scope="all"`), so secondary-only records are included regardless of recency.
- Citation keys identify catalogue records.
- Within a source, the first usable occurrence of a citation key wins.
- Across sources, primary metadata wins for shared citation keys.
- DOI values are non-unique indexed attributes and are **not** a de-duplication rule.
- Catalogue parsing accepts the formats supported by `ReferenceCatalog` (CSL arrays and `{ "items": [...] }`). `find-bib` does not implement additional container formats.
- Primary readiness/errors are reported by the catalogue rather than by a separate `find-bib` filesystem check.

`ZOTERO_RECENT_DAYS` affects ordinary automatic ranked search elsewhere. It does not restrict `find-bib`, because this CLI explicitly filters the complete canonical union.

## Inputs

### Field filters

Each filter may be repeated. Values are case-insensitive substrings after simple normalization.

- `--author TXT`
- `--year TXT`
- `--doi TXT`
- `--title TXT`
- `--abstract TXT`

A field flag without a following value is a usage error.

### Output control

- `--cat` — emit BibTeX for matching keys by invoking `cite2bib`.

### Help

- `-h`, `--help` — concise agent-oriented help.
- `--human` — expanded human-oriented help. As with the other tools, `--human` may only be combined with help flags.

There are no `--limit` or `--json` options.

## Matching semantics

- **AND across different fields.** Every field for which at least one filter was supplied must match.
- **OR within one field.** Repeating a field broadens that field, e.g. `--author steward --author velleman` matches either author.
- Match is substring-based after:
  - lower/case folding,
  - removal of `{` and `}` braces,
  - whitespace collapse and trimming.
- Missing data fails a filter for that field.

Field extraction:

- author: CSL `.author`; arrays of name objects are rendered as `Family, Given` and joined with `; `. A legacy `.authors` value may be used when `.author` is absent.
- year: first value of `.issued["date-parts"][0]` when present; otherwise the first 19xx/20xx year found in an issued literal/value.
- DOI: `.DOI`, falling back to `.doi`.
- title: `.title`.
- abstract: `.abstract`.

The matching layer operates only on canonical catalogue entries supplied by `ReferenceCatalog`; it never opens the bibliography source files itself.

## Output

### Default

Print the canonical citation key for each match, one per line, in canonical catalogue order. Keep stdout free of diagnostics.

### `--cat`

For each matching key, invoke `cite2bib <key>` and allow its BibTeX output to pass through. Catalogue membership does not imply BibTeX availability: a secondary-only CSL record may therefore be discoverable by `find-bib` while `--cat` fails for that key.

If any matched key fails in `cite2bib`, `find-bib --cat` returns non-zero rather than silently presenting a partial export as complete.

## Exit codes

- `0`: at least one requested result was emitted and, for `--cat`, every matched key emitted successfully.
- `1`: no catalogue records matched, or at least one matched key could not be emitted by `cite2bib`.
- `2`: usage/configuration/runtime setup error, including unavailable required primary catalogue data, missing Python canonical runtime, or missing `cite2bib` for `--cat`.

## Dependencies

- Python 3.
- The Python `agent-tools` package containing `ReferenceCatalog` and its dependencies. `install.sh` installs this into the tool installation directory for CLI use.
- `cite2bib` only when `--cat` is requested.

`find-bib` no longer depends on `jq` and contains no CSL-JSON parser of its own.

## Performance

Load/refresh the canonical catalogue once for the command, enumerate the complete canonical union through the public catalogue API, and perform the field filters in memory. Do not perform per-record filesystem reads or create a second source index.

## Examples

Find a key from several fields:

```bash
find-bib --author steward --year 2009 --title "animal agency"
```

Search either of two authors:

```bash
find-bib --author steward --author velleman
```

Search abstracts across the complete catalogue, including secondary-only records:

```bash
find-bib --abstract "joint action"
```

Emit BibTeX where a local BibTeX artifact exists:

```bash
find-bib --author agrillo --year 2017 --cat
```

## Non-goals

- No fuzzy ranking or relevance scoring.
- No Markdown/full-text search.
- No network lookup or DOI resolution.
- No bibliography de-duplication, preferred-key selection, or aliasing.
- No direct parsing/filtering of `BIB_JSON`/`ZOTERO_JSON` outside `ReferenceCatalog`.
