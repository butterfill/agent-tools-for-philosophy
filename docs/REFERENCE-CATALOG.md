# Reference catalogue contract

`ReferenceCatalog` is the shared bibliography/search boundary for TypeScript and Python consumers.

## Source policy

1. The primary source (`BIB_JSON`) is authoritative and required at startup/load.
2. The secondary source (`ZOTERO_JSON`) is optional and supplies complete-library membership.
3. Within each source the first usable occurrence of a key wins. Across sources primary metadata wins.
4. Ordinary automatic search ranks primary records together with secondary-only records accessed within `ZOTERO_RECENT_DAYS` (default 14).
5. A citation-key-shaped query, or a query without a plausible primary match, widens to the complete canonical union before ranking.
6. Explicit `secondary` scope means secondary membership but still uses primary metadata for shared keys.
7. Candidate sets are ranked once; results from separate source searches are never score-merged.

## Identity and lookup

Identity is a non-empty CSL `citation-key`, falling back to `id`; numeric identifiers are strings. Keys are not required to match BibTeX conventions. Exact, relaxed-key and normalized-DOI lookup all operate on the complete canonical union.

The catalogue keeps an original authoritative CSL row separately from the normalized searchable record. This lets consumers return original CSL while using a stable canonical key internally.

## Ranking compatibility

The internal ranker preserves the historical agent-tools ordering, including padded candidate behavior. Plausibility is a separate widening heuristic and must not be used as a relevance filter. `searchHits()` exposes ranking evidence without changing `search()` ordering.

Python and TypeScript intentionally use different fuzzy-search libraries; shared corpus tests define behavioral expectations rather than numerical score equality.

## Lifecycle

A valid empty source clears that source. Malformed JSON, unusable non-empty CSL, deletion, and read races retain the last good snapshot. TypeScript polls and exposes revisions; Python refreshes lazily. Recency is recomputed when a snapshot is rebuilt, not continuously while a snapshot remains unchanged.

## Out of scope for Phase 1

The shell `find-bib` tool still has its independent field-filter semantics. It must migrate to this catalogue in Phase 2 before the overall multi-source project is considered complete.
