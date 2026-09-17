# TypeScript Developer Guide: `agent-tools`

The package exposes `AgentTools` for local document actions and `ReferenceCatalog` for bibliography identity/search. The old public `Bibliography` class was removed in 0.2.0; the in-memory ranker is now an implementation detail so applications cannot accidentally reimplement source policy.

## Configuration

`ReferenceCatalog` uses:

- `BIB_JSON` — authoritative/cited CSL-JSON source; default `~/endnote/phd_biblio.json`.
- `ZOTERO_JSON` — complete/secondary CSL-JSON source; default `~/endnote/zotero-export.json`.
- `ZOTERO_RECENT_DAYS` — recent-secondary window; default `14`.

The primary source must be usable at `start()`. The secondary source is optional. Duplicate keys keep the first record within a source and primary metadata wins when a key occurs in both sources.

## Reference search

```ts
import { ReferenceCatalog } from '@butterfill/agent-tools';

const catalog = new ReferenceCatalog();
await catalog.start();

// Automatic policy: primary plus recent secondary-only records, widening to
// the complete union for citation-key-shaped queries or weak primary matches.
const results = catalog.search('davidson reasons', 5);

// Applications can request source membership structurally. UI tokens such as
// bibq-w's !z are intentionally not part of this API.
const secondary = catalog.search('mind', 20, 'secondary');
const allRefs = catalog.search('mind', 20, 'all');

const relaxed = catalog.resolveKey('davidson1963actions');
const doi = catalog.getByDoi('https://doi.org/10.1000/example');

catalog.close();
```

`search()` returns ranked candidates without a relevance threshold. `searchHits()` returns exactly the same ordering with raw score and field evidence for consumers that need to interpret ranking. Scores are implementation details and are not a cross-language contract.

`getByKey()` is exact. `resolveKey()` adds case-insensitive and punctuation-insensitive lookup when unique. `getByDoi()` resolves a normalized DOI when unique. `getRawByKey()` preserves the authoritative CSL row when a consumer must return CSL without catalogue identity normalization.

The TypeScript catalogue polls for file changes (two seconds by default), publishes replacement indexes atomically, exposes `revision`, and retains the last good source snapshot across malformed or missing intermediate writes.

## `AgentTools`

```ts
import { AgentTools } from '@butterfill/agent-tools';

const client = new AgentTools();
const markdown = await client.getMdContent('vesper:2012_jumping');
const pdfPath = await client.getPdfPath('vesper:2012_jumping');
const bibtex = await client.getBibEntry('vesper:2012_jumping');
```

Catalogue membership and local artifacts are deliberately separate: a reference may be searchable even when no Markdown, PDF or BibTeX is available.
