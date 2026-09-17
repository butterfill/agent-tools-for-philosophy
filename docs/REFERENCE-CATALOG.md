# Reference catalogue contract

`ReferenceCatalog` is the shared bibliography/search boundary for TypeScript and Python consumers.

## Basic principles

1. **Citation keys identify catalogue records. DOIs are non-unique indexed attributes.** A DOI may be asserted by zero, one, or several records, so DOI lookup returns every matching record and never silently collapses or arbitrarily selects among them.
2. **Catalogue readiness is a property of the usable snapshot, not the current filesystem state.** A consumer should ask the catalogue whether it is ready rather than re-checking configured paths. Once a usable primary snapshot has loaded, transient deletion, malformed writes, or read races retain the last-good snapshot and the catalogue remains ready.
3. **Source selection happens before ranking.** The selected candidate set is ranked once; ranked lists from separate sources are never merged.
4. **Bibliography membership and local artifacts are separate concerns.** A catalogue record does not imply that Markdown, PDF, abstract, or BibTeX material exists locally.

## Source policy

1. The primary source (`BIB_JSON`) is authoritative and required at startup/load.
2. The secondary source (`ZOTERO_JSON`) is optional and supplies complete-library membership.
3. Within each source the first usable occurrence of a key wins. Across sources primary metadata wins.
4. Ordinary automatic search ranks primary records together with secondary-only records accessed within `ZOTERO_RECENT_DAYS` (default 14).
5. A citation-key-shaped query, or a query without a plausible primary match, widens to the complete canonical union before ranking.
6. Explicit `secondary` scope means secondary membership but still uses primary metadata for shared keys.
7. Candidate sets are ranked once; results from separate source searches are never score-merged.

## Identity and lookup

Identity is a non-empty CSL `citation-key`, falling back to `id`; numeric identifiers are strings. Keys are not required to match BibTeX conventions. Exact and relaxed-key lookup operate over the complete canonical union.

DOI is deliberately different from key identity. `findByDoi()` / `find_by_doi()` normalizes `doi:` and doi.org forms and returns every canonical record that asserts that DOI, in catalogue order. Multiple results are evidence of shared DOI association, not proof that the records are bibliographic duplicates.

The catalogue keeps an original authoritative CSL row separately from the normalized searchable record. This lets consumers return original CSL while using a stable canonical key internally.

## Ranking compatibility

The internal ranker preserves the historical agent-tools ordering, including padded candidate behavior. Plausibility is a separate widening heuristic and must not be used as a relevance filter. `searchHits()` exposes ranking evidence without changing `search()` ordering.

Python and TypeScript intentionally use different fuzzy-search libraries; shared corpus tests define behavioral expectations rather than numerical score equality.

## Lifecycle and readiness

A valid empty source clears that source. Malformed JSON, unusable non-empty CSL, deletion, and read races retain the last good snapshot.

`ready` means that the catalogue has a usable primary snapshot. It therefore remains true while a previously loaded primary source is temporarily absent or malformed. A consumer should use `ready` to advertise catalogue-backed capabilities rather than checking whether `BIB_JSON` currently exists on disk.

TypeScript callers establish the initial snapshot with `start()` and then receive polling/revision updates. Python refreshes lazily, including when `ready` is queried. Recency is recomputed when a snapshot is rebuilt, not continuously while a snapshot remains unchanged.

## Out of scope for Phase 1

The shell `find-bib` tool still has its independent field-filter semantics. It must migrate to this catalogue in Phase 2 before the overall multi-source project is considered complete.

Bibliographic de-duplication is also a later project. The Phase 1 catalogue preserves distinct citation keys even when records share a DOI; any future preferred-key or alias system must preserve historically used citation keys rather than treating DOI equality alone as sufficient evidence for destructive merging.
