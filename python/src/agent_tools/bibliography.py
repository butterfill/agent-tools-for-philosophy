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
    return any(candidate == token or candidate.startswith(token) or fuzz.ratio(token, candidate) >= 82 for candidate in field_tokens)

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
            year = self._get_year(entry); authors = self._get_authors(entry); title = str(entry.get("title") or ""); key = str(entry.get("id") or entry.get("citation-key") or "")
            full = " ".join([year, authors, title, key]); self._search_corpus.append(full)
            self._search_records.append({"entry":entry,"key":key,"key_norm":normalize_search_text(key),"key_compact":compact_search_text(key),"key_tokens":_tokens(key),"authors":authors,"authors_norm":normalize_search_text(authors),"authors_tokens":_tokens(authors),"title":title,"title_norm":normalize_search_text(title),"title_tokens":_tokens(title),"year":year,"year_norm":normalize_search_text(year),"year_tokens":_tokens(year),"full":full,"full_norm":normalize_search_text(full),"full_tokens":_tokens(full)})
    @classmethod
    def from_entries(cls, entries: Iterable[CslEntry]) -> "BibliographyIndex": return cls(entries)
    def __len__(self) -> int: return len(self.entries)
    def has_plausible_match(self, query: str) -> bool:
        if not query.strip(): return bool(self.entries)
        info = self._query_info(query)
        return any(self._is_key_candidate(info, record) or (info["tokens"] and all(_plausible_token_matches(token, record["full_tokens"]) for token in info["tokens"])) for record in self._search_records)
    def search(self, query: str, limit: int = 20) -> list[CslEntry]: return [hit.entry for hit in self.search_hits(query, limit)]
    def search_hits(self, query: str, limit: int = 20) -> list[SearchHit]:
        if not self.entries or limit <= 0: return []
        if not query: return [SearchHit(entry=e, score=0.0, match_basis=()) for e in self.entries[:limit]]
        q = self._query_info(query); candidates = self._candidate_indexes(q, limit)
        ranked = sorted(((idx,self._search_records[idx],self._score_record(q,self._search_records[idx])) for idx in candidates), key=lambda row:(-row[2],row[0]))
        return [SearchHit(entry=record["entry"], score=float(score), match_basis=self._match_basis(q,record)) for _,record,score in ranked[:limit]]
    @staticmethod
    def _get_authors(entry):
        authors=entry.get("author")
        return " ".join(str(a.get("family","")) for a in authors if isinstance(a,dict)) if isinstance(authors,list) else ""
    @staticmethod
    def _get_year(entry):
        try:
            issued=entry.get("issued"); parts=issued.get("date-parts") if issued else None; first=parts[0] if parts else None
            return str(first[0]) if isinstance(first,list) and first else ""
        except Exception: return ""
    @staticmethod
    def _query_info(query): return {"raw":str(query or ""),"norm":normalize_search_text(query),"compact":compact_search_text(query),"tokens":_tokens(query)}
    def _candidate_indexes(self,q,limit):
        candidate_limit=min(len(self.entries),max(limit*10,200)); candidates={idx for _,_,idx in process.extract(q["raw"],self._search_corpus,limit=candidate_limit,scorer=fuzz.partial_ratio)}
        for idx,record in enumerate(self._search_records):
            if self._is_key_candidate(q,record) or self._has_full_token_coverage(q,record): candidates.add(idx)
        if len(candidates)<limit: candidates.update(range(min(len(self.entries),limit)))
        return candidates
    @staticmethod
    def _is_key_candidate(q,r):
        qc=q["compact"]; kc=r["key_compact"]; return bool(qc and kc and (qc==kc or kc.startswith(qc) or qc in kc))
    @staticmethod
    def _has_full_token_coverage(q,r): return bool(q["tokens"]) and all(_token_matches(t,r["full_tokens"]) for t in q["tokens"])
    @staticmethod
    def _score_record(q,r):
        qn=q["norm"]; qc=q["compact"]; qt=q["tokens"]
        score=max(fuzz.WRatio(qn,r["full_norm"])*.55,fuzz.partial_ratio(qn,r["full_norm"])*.45,fuzz.token_set_ratio(qn,r["full_norm"])*.55,fuzz.WRatio(qn,r["key_norm"])*.90,fuzz.WRatio(qn,r["authors_norm"])*.75,fuzz.WRatio(qn,r["title_norm"])*.70)
        if qc and r["key_compact"]:
            score=max(score,fuzz.partial_ratio(qc,r["key_compact"])*.95,fuzz.WRatio(qc,r["key_compact"])*.90)
            if qc==r["key_compact"]: score+=50
            elif len(qc)>=3 and r["key_compact"].startswith(qc): score+=25
        if not qt: return float(score)
        score += 8*sum(1 for t in qt if _token_matches(t,r["full_tokens"]))/len(qt)
        if any(_token_matches(t,r["authors_tokens"]) for t in qt) and any(_token_matches(t,r["title_tokens"]) or _token_matches(t,r["key_tokens"]) for t in qt): score+=12
        if any(_token_matches(t,r["year_tokens"]) for t in qt): score+=8
        return float(score)
    @staticmethod
    def _match_basis(q,r):
        basis=set(); qc=q["compact"]; kc=r["key_compact"]
        if qc and kc and (qc==kc or (len(qc)>=3 and kc.startswith(qc))): basis.add("key")
        if any(_token_matches(t,r["authors_tokens"]) for t in q["tokens"]): basis.add("author")
        if any(_token_matches(t,r["title_tokens"]) for t in q["tokens"]): basis.add("title")
        if any(_token_matches(t,r["year_tokens"]) for t in q["tokens"]): basis.add("year")
        return tuple(sorted(basis))
