from __future__ import annotations

import re
import unicodedata
from dataclasses import dataclass
from typing import Any, Iterable

from rapidfuzz import fuzz, process

CslEntry = dict[str, Any]


def normalize_search_text(value: Any) -> str:
    text = unicodedata.normalize("NFKD", str(value or ""))
    text = text.encode("ascii", "ignore").decode("ascii").lower()
    text = re.sub(r"[^a-z0-9]+", " ", text)
    return re.sub(r"\s+", " ", text).strip()


def compact_search_text(value: Any) -> str:
    return re.sub(r"[^a-z0-9]+", "", normalize_search_text(value))


def _tokens(value: Any) -> list[str]:
    normalized = normalize_search_text(value)
    return normalized.split() if normalized else []


def _token_matches(token: str, field_tokens: list[str]) -> bool:
    return any(candidate == token or candidate.startswith(token) for candidate in field_tokens)


def _plausible_token_matches(token: str, field_tokens: list[str]) -> bool:
    return any(
        candidate == token
        or candidate.startswith(token)
        or fuzz.ratio(token, candidate) >= 82
        for candidate in field_tokens
    )


@dataclass(frozen=True, slots=True)
class SearchHit:
    entry: CslEntry
    score: float
    match_basis: tuple[str, ...]


class BibliographyIndex:
    """Pure in-memory bibliography ranker; source/file policy lives elsewhere."""

    def __init__(self, entries: Iterable[CslEntry]):
        self.entries = list(entries)
        self._search_corpus: list[str] = []
        self._search_records: list[dict[str, Any]] = []
        for entry in self.entries:
            year = self._get_year(entry)
            authors = self._get_authors(entry)
            title = str(entry.get("title") or "")
            key = str(entry.get("id") or entry.get("citation-key") or "")
            full = " ".join([year, authors, title, key])
            self._search_corpus.append(full)
            self._search_records.append(
                {
                    "entry": entry,
                    "key": key,
                    "key_norm": normalize_search_text(key),
                    "key_compact": compact_search_text(key),
                    "key_tokens": _tokens(key),
                    "authors": authors,
                    "authors_norm": normalize_search_text(authors),
                    "authors_tokens": _tokens(authors),
                    "title": title,
                    "title_norm": normalize_search_text(title),
                    "title_tokens": _tokens(title),
                    "year": year,
                    "year_norm": normalize_search_text(year),
                    "year_tokens": _tokens(year),
                    "full": full,
                    "full_norm": normalize_search_text(full),
                    "full_tokens": _tokens(full),
                }
            )

    @classmethod
    def from_entries(cls, entries: Iterable[CslEntry]) -> "BibliographyIndex":
        return cls(entries)

    def __len__(self) -> int:
        return len(self.entries)

    def has_plausible_match(self, query: str) -> bool:
        if not query.strip():
            return bool(self.entries)
        info = self._query_info(query)
        return any(
            self._is_key_candidate(info, record)
            or (
                info["tokens"]
                and all(
                    _plausible_token_matches(token, record["full_tokens"])
                    for token in info["tokens"]
                )
            )
            for record in self._search_records
        )

    def search(self, query: str, limit: int = 20) -> list[CslEntry]:
        return [hit.entry for hit in self.search_hits(query, limit)]

    def search_hits(self, query: str, limit: int = 20) -> list[SearchHit]:
        if not self.entries or limit <= 0:
            return []
        if not query:
            return [
                SearchHit(entry=entry, score=0.0, match_basis=())
                for entry in self.entries[:limit]
            ]

        query_info = self._query_info(query)
        candidate_indexes = self._candidate_indexes(query_info, limit)
        ranked = sorted(
            (
                (
                    idx,
                    self._search_records[idx],
                    self._score_record(query_info, self._search_records[idx]),
                )
                for idx in candidate_indexes
            ),
            key=lambda row: (-row[2], row[0]),
        )
        return [
            SearchHit(
                entry=record["entry"],
                score=float(score),
                match_basis=self._match_basis(query_info, record),
            )
            for _, record, score in ranked[:limit]
        ]

    @staticmethod
    def _get_authors(entry: CslEntry) -> str:
        authors = entry.get("author")
        if isinstance(authors, list):
            return " ".join(
                str(author.get("family", ""))
                for author in authors
                if isinstance(author, dict)
            )
        return ""

    @staticmethod
    def _get_year(entry: CslEntry) -> str:
        try:
            issued = entry.get("issued")
            if issued:
                date_parts = issued.get("date-parts")
                if date_parts and isinstance(date_parts, list):
                    first = date_parts[0]
                    if isinstance(first, list) and first:
                        return str(first[0])
        except Exception:
            pass
        return ""

    @staticmethod
    def _query_info(query: str) -> dict[str, Any]:
        return {
            "raw": str(query or ""),
            "norm": normalize_search_text(query),
            "compact": compact_search_text(query),
            "tokens": _tokens(query),
        }

    def _candidate_indexes(self, query: dict[str, Any], limit: int) -> set[int]:
        candidate_limit = min(len(self.entries), max(limit * 10, 200))
        candidates = {
            idx
            for _, _, idx in process.extract(
                query["raw"],
                self._search_corpus,
                limit=candidate_limit,
                scorer=fuzz.partial_ratio,
            )
        }
        for idx, record in enumerate(self._search_records):
            if self._is_key_candidate(query, record) or self._has_full_token_coverage(query, record):
                candidates.add(idx)
        if len(candidates) < limit:
            candidates.update(range(min(len(self.entries), limit)))
        return candidates

    @staticmethod
    def _is_key_candidate(query: dict[str, Any], record: dict[str, Any]) -> bool:
        query_compact = query["compact"]
        key_compact = record["key_compact"]
        return bool(
            query_compact
            and key_compact
            and (
                query_compact == key_compact
                or key_compact.startswith(query_compact)
                or query_compact in key_compact
            )
        )

    @staticmethod
    def _has_full_token_coverage(query: dict[str, Any], record: dict[str, Any]) -> bool:
        query_tokens = query["tokens"]
        return bool(query_tokens) and all(
            _token_matches(token, record["full_tokens"]) for token in query_tokens
        )

    @staticmethod
    def _score_record(query: dict[str, Any], record: dict[str, Any]) -> float:
        query_norm = query["norm"]
        query_compact = query["compact"]
        query_tokens = query["tokens"]

        score = max(
            fuzz.WRatio(query_norm, record["full_norm"]) * 0.55,
            fuzz.partial_ratio(query_norm, record["full_norm"]) * 0.45,
            fuzz.token_set_ratio(query_norm, record["full_norm"]) * 0.55,
            fuzz.WRatio(query_norm, record["key_norm"]) * 0.90,
            fuzz.WRatio(query_norm, record["authors_norm"]) * 0.75,
            fuzz.WRatio(query_norm, record["title_norm"]) * 0.70,
        )

        if query_compact and record["key_compact"]:
            score = max(
                score,
                fuzz.partial_ratio(query_compact, record["key_compact"]) * 0.95,
                fuzz.WRatio(query_compact, record["key_compact"]) * 0.90,
            )
            if query_compact == record["key_compact"]:
                score += 50
            elif len(query_compact) >= 3 and record["key_compact"].startswith(query_compact):
                score += 25

        if not query_tokens:
            return float(score)

        covered = sum(
            1 for token in query_tokens if _token_matches(token, record["full_tokens"])
        )
        score += 8 * covered / len(query_tokens)

        has_author_token = any(
            _token_matches(token, record["authors_tokens"]) for token in query_tokens
        )
        has_title_or_key_token = any(
            _token_matches(token, record["title_tokens"])
            or _token_matches(token, record["key_tokens"])
            for token in query_tokens
        )
        if has_author_token and has_title_or_key_token:
            score += 12

        if any(_token_matches(token, record["year_tokens"]) for token in query_tokens):
            score += 8

        return float(score)

    @staticmethod
    def _match_basis(query: dict[str, Any], record: dict[str, Any]) -> tuple[str, ...]:
        basis: set[str] = set()
        query_compact = query["compact"]
        key_compact = record["key_compact"]
        if query_compact and key_compact and (
            query_compact == key_compact
            or (len(query_compact) >= 3 and key_compact.startswith(query_compact))
        ):
            basis.add("key")
        tokens = query["tokens"]
        if any(_token_matches(token, record["authors_tokens"]) for token in tokens):
            basis.add("author")
        if any(_token_matches(token, record["title_tokens"]) for token in tokens):
            basis.add("title")
        if any(_token_matches(token, record["year_tokens"]) for token in tokens):
            basis.add("year")
        return tuple(sorted(basis))
