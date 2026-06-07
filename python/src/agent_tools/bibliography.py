import json
import os
import re
import unicodedata
from rapidfuzz import process, fuzz


def _normalize(value):
    text = unicodedata.normalize("NFKD", str(value or ""))
    text = text.encode("ascii", "ignore").decode("ascii")
    text = text.lower()
    text = re.sub(r"[^a-z0-9]+", " ", text)
    return re.sub(r"\s+", " ", text).strip()


def _compact(value):
    return re.sub(r"[^a-z0-9]+", "", _normalize(value))


def _tokens(value):
    normalized = _normalize(value)
    if not normalized:
        return []
    return normalized.split()


def _token_matches(token, field_tokens):
    return any(candidate == token or candidate.startswith(token) for candidate in field_tokens)


class Bibliography:
    def __init__(self, json_path: str = None):
        self.path = json_path or os.environ.get("BIB_JSON", os.path.expanduser("~/endnote/phd_biblio.json"))
        self.entries = []
        self._search_corpus = []
        self._search_records = []
        # Note: constructor no longer loads automatically to avoid blocking.
        self._loaded = False

    def __len__(self):
        return len(self.entries)

    def load(self):
        if not os.path.exists(self.path):
            self.entries = []
            self._search_corpus = []
            self._search_records = []
            return

        with open(self.path, 'r', encoding='utf-8') as f:
            data = json.load(f)
            self.entries = data.get('items', data) if isinstance(data, dict) else data
        
        # Prepare search records for field-aware ranking.
        self._search_corpus = []
        self._search_records = []
        for e in self.entries:
            year = self._get_year(e)
            authors_str = self._get_authors(e)
            title = str(e.get('title') or '')
            key = str(e.get('id') or e.get('citation-key') or '')
            parts = [
                year,
                authors_str,
                title,
                key
            ]
            full = " ".join(parts)
            self._search_corpus.append(full)
            self._search_records.append({
                "entry": e,
                "key": key,
                "key_norm": _normalize(key),
                "key_compact": _compact(key),
                "key_tokens": _tokens(key),
                "authors": authors_str,
                "authors_norm": _normalize(authors_str),
                "authors_tokens": _tokens(authors_str),
                "title": title,
                "title_norm": _normalize(title),
                "title_tokens": _tokens(title),
                "year": year,
                "year_norm": _normalize(year),
                "year_tokens": _tokens(year),
                "full": full,
                "full_norm": _normalize(full),
                "full_tokens": _tokens(full),
            })
        self._loaded = True

    async def load_async(self):
        import asyncio
        await asyncio.to_thread(self.load)

    def search(self, query: str, limit: int = 20):
        if not self._loaded and not self.entries:
             # Logic implies it's empty, but let's be explicitly silent 
             # only if we attempted to load. 
             pass 
         
        if not self.entries:
            return []
        if not query: return self.entries[:limit]

        query_info = self._query_info(query)
        candidate_indexes = self._candidate_indexes(query_info, limit)
        ranked = sorted(
            ((idx, self._search_records[idx]) for idx in candidate_indexes),
            key=lambda pair: (-self._score_record(query_info, pair[1]), pair[0])
        )
        return [record["entry"] for _, record in ranked[:limit]]

    @staticmethod
    def _get_authors(e):
        authors_list = e.get('author')
        if isinstance(authors_list, list):
            return " ".join([a.get('family', '') for a in authors_list if isinstance(a, dict)])
        return ""

    @staticmethod
    def _get_year(e):
        try:
            issued = e.get('issued')
            if issued:
                date_parts = issued.get('date-parts')
                # Expect list of lists: [[2018, 1, 1]] or [[2018]]
                if date_parts and isinstance(date_parts, list) and len(date_parts) > 0:
                    first_part = date_parts[0]
                    if isinstance(first_part, list) and len(first_part) > 0:
                        return str(first_part[0])
        except Exception:
            pass
        return ""

    @staticmethod
    def _query_info(query):
        return {
            "raw": str(query or ""),
            "norm": _normalize(query),
            "compact": _compact(query),
            "tokens": _tokens(query),
        }

    def _candidate_indexes(self, query, limit):
        candidate_limit = min(len(self.entries), max(limit * 10, 200))
        candidates = {
            idx for _, _, idx in process.extract(
                query["raw"],
                self._search_corpus,
                limit=candidate_limit,
                scorer=fuzz.partial_ratio
            )
        }

        for idx, record in enumerate(self._search_records):
            if self._is_key_candidate(query, record) or self._has_full_token_coverage(query, record):
                candidates.add(idx)

        if len(candidates) < limit:
            candidates.update(range(min(len(self.entries), limit)))

        return candidates

    @staticmethod
    def _is_key_candidate(query, record):
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
    def _has_full_token_coverage(query, record):
        query_tokens = query["tokens"]
        if not query_tokens:
            return False
        return all(_token_matches(token, record["full_tokens"]) for token in query_tokens)

    @staticmethod
    def _score_record(query, record):
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
            return score

        field_tokens = {
            "key": record["key_tokens"],
            "authors": record["authors_tokens"],
            "title": record["title_tokens"],
            "year": record["year_tokens"],
            "full": record["full_tokens"],
        }
        covered = sum(1 for token in query_tokens if _token_matches(token, field_tokens["full"]))
        score += 8 * covered / len(query_tokens)

        has_author_token = any(_token_matches(token, field_tokens["authors"]) for token in query_tokens)
        has_title_or_key_token = any(
            _token_matches(token, field_tokens["title"]) or _token_matches(token, field_tokens["key"])
            for token in query_tokens
        )
        if has_author_token and has_title_or_key_token:
            score += 12

        if any(_token_matches(token, field_tokens["year"]) for token in query_tokens):
            score += 8

        return score
