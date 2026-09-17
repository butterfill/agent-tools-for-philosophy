# Python Developer Guide: `agent-tools`

The Python package exposes two public concerns: `AgentTools` for local document actions and `ReferenceCatalog` for bibliography identity/search. The old file-backed `Bibliography` API was removed in 0.2.0; search indexes are now an implementation detail of the catalogue.

## Configuration

`ReferenceCatalog` uses:

- `BIB_JSON` — authoritative/cited CSL-JSON source; default `~/endnote/phd_biblio.json`.
- `ZOTERO_JSON` — complete/secondary CSL-JSON source; default `~/endnote/zotero-export.json`.
- `ZOTERO_RECENT_DAYS` — recent-secondary window; default `14`.
- `PAPERS_DIR` and `BIB_FILE` remain relevant to `AgentTools` shell-backed document actions.

The primary source is required when the catalogue is loaded. The secondary source is optional. Duplicate keys keep their first record within a source; primary metadata wins across sources.

## Reference search

```python
from agent_tools import ReferenceCatalog

catalog = ReferenceCatalog()
catalog.load()  # or: await catalog.load_async()

# Automatic policy: primary + recent secondary-only records, widening to the
# complete union for citation-key-shaped queries or weak primary matches.
for entry in catalog.search("davidson reasons", limit=5):
    print(entry["id"], entry.get("title"))

# Structured scopes are available to applications; command syntax belongs in
# the application rather than the library.
secondary = catalog.search("mind", limit=20, scope="secondary")
all_refs = catalog.search("mind", limit=20, scope="all")

record = catalog.resolve_key("davidson1963actions")
by_doi = catalog.get_by_doi("https://doi.org/10.1000/example")
```

`search()` always returns ranked candidates and does not apply a relevance threshold. `search_hits()` returns the same ordering with raw ranking scores and field evidence for consumers such as citation resolvers. Scores are implementation details and should not be compared across language bindings.

`get_by_key()` is exact. `resolve_key()` adds case-insensitive and punctuation-insensitive lookup when the relaxed form is unique. `get_by_doi()` normalizes `doi:` and doi.org forms and resolves only unique DOI membership.

The Python catalogue refreshes source metadata lazily on public operations and atomically keeps the last good snapshot when a source is temporarily unreadable or malformed.

## `AgentTools`

```python
from agent_tools import AgentTools

client = AgentTools()
markdown = client.get_md_content("vesper:2012_jumping")
pdf_path = client.get_pdf_path("vesper:2012_jumping")
bibtex = client.get_bib_entry("vesper:2012_jumping")
```

Bibliography membership and local artifacts are deliberately separate: a catalogue record does not guarantee that Markdown, PDF or BibTeX exists.
