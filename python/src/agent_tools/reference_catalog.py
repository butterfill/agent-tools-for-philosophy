from __future__ import annotations

import asyncio, json, os, re, time
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Callable, Literal
from .bibliography import BibliographyIndex, CslEntry, SearchHit, compact_search_text

ReferenceScope = Literal["auto", "primary", "all", "secondary"]

@dataclass(frozen=True, slots=True)
class ReferenceRecord:
    key: str; entry: CslEntry; raw_entry: CslEntry; in_primary: bool; in_secondary: bool
@dataclass(frozen=True, slots=True)
class ReferenceSearchHit:
    key: str; entry: CslEntry; raw_entry: CslEntry; score: float; match_basis: tuple[str,...]; in_primary: bool; in_secondary: bool; secondary_only: bool
@dataclass(frozen=True, slots=True)
class _SourceEntry:
    key: str; raw_entry: CslEntry; entry: CslEntry
@dataclass(frozen=True, slots=True)
class _SourceSnapshot:
    signature: str=""; raw: str=""; entries: tuple[_SourceEntry,...]=()
@dataclass(frozen=True, slots=True)
class _CatalogSnapshot:
    primary: BibliographyIndex; ordinary: BibliographyIndex; all: BibliographyIndex; secondary: BibliographyIndex; primary_keys: frozenset[str]; records: dict[str,ReferenceRecord]; folded_keys: dict[str,str|None]; compact_keys: dict[str,str|None]; dois: dict[str,str|None]; ordered_keys: tuple[str,...]

def looks_like_citation_key(query: str) -> bool: return re.match(r"^[^\s:]+:?\d{4}_\S+$",query) is not None

def parse_references(raw: str) -> tuple[_SourceEntry,...]:
    data=json.loads(raw)
    if isinstance(data,list): rows=data
    elif isinstance(data,dict) and isinstance(data.get("items"),list): rows=data["items"]
    else: raise ValueError("Expected a CSL-JSON array or { items: [] }")
    entries={}
    for row in rows:
        if not isinstance(row,dict): continue
        key_value=row.get("citation-key") or row.get("id")
        if not isinstance(key_value,(str,int,float)) or isinstance(key_value,bool): continue
        key=str(key_value).strip()
        if not key or key in entries: continue
        raw_entry=dict(row); entries[key]=_SourceEntry(key,raw_entry,{**raw_entry,"id":key,"citation-key":key})
    if rows and not entries: raise ValueError("No usable citation keys in nonempty source")
    return tuple(entries.values())

def is_recent(entry:CslEntry, now_ms:float, days:float)->bool:
    try: parts=entry.get("accessed",{}).get("date-parts",[])[0]
    except (AttributeError,IndexError,TypeError): return False
    if not isinstance(parts,list) or len(parts)<3: return False
    parsed=[]
    for value in parts[:3]:
        if isinstance(value,bool): return False
        if isinstance(value,int): parsed.append(value)
        elif isinstance(value,float) and value.is_integer(): parsed.append(int(value))
        elif isinstance(value,str) and value.isdigit(): parsed.append(int(value))
        else: return False
    year,month,day=parsed
    if year<1000 or not 1<=month<=12 or not 1<=day<=31: return False
    try:
        from datetime import datetime,timezone
        stamp=datetime(year,month,day,tzinfo=timezone.utc).timestamp()*1000
    except ValueError: return False
    age=now_ms-stamp; return 0<=age<=days*86_400_000

def normalize_doi(value:Any)->str:
    text=str(value or "").strip(); text=re.sub(r"^doi\s*:\s*","",text,flags=re.I); text=re.sub(r"^https?://(?:dx\.)?doi\.org/","",text,flags=re.I); return text.strip().casefold()

class ReferenceCatalog:
    def __init__(self, primary_path=None, secondary_path=None, *, recent_days=None, now:Callable[[],float]|None=None, warn:Callable[[str],None]|None=None):
        self.primary_path=Path(primary_path or os.environ.get("BIB_JSON") or os.path.expanduser("~/endnote/phd_biblio.json")); self.secondary_path=Path(secondary_path or os.environ.get("ZOTERO_JSON") or os.path.expanduser("~/endnote/zotero-export.json"))
        env_recent=os.environ.get("ZOTERO_RECENT_DAYS"); self.recent_days=float(recent_days if recent_days is not None else (env_recent or 14))
        if not self.recent_days>=0 or self.recent_days==float("inf"): raise ValueError("recent_days must be non-negative and finite")
        self._now=now or (lambda:time.time()*1000); self._warn=warn or (lambda message:print(message,file=__import__("sys").stderr)); self._sources=[_SourceSnapshot(),_SourceSnapshot()]; self._failures={}; self._revision=0; self._loaded=False; self._snapshot=self._build(self._sources)
    @property
    def revision(self): return self._revision
    def __len__(self): self._ensure_fresh(); return len(self._snapshot.primary)
    def keys(self): self._ensure_fresh(); return list(self._snapshot.ordered_keys)
    def load(self):
        self.reload(); self._loaded=True
        if not self._sources[0].signature:
            path=str(self.primary_path); raise ValueError(f"Primary bibliography unavailable ({path}): {self._failures.get(path,'no usable primary snapshot')}")
    async def load_async(self): await asyncio.to_thread(self.load)
    def reload(self):
        nxt=[self._read_source(self.primary_path,self._sources[0],optional=False),self._read_source(self.secondary_path,self._sources[1],optional=True)]
        if any(a.raw!=b.raw for a,b in zip(nxt,self._sources)):
            try: snapshot=self._build(nxt)
            except Exception as exc: self._warn(f"Bibliography index reload failed: {exc}")
            else: self._snapshot=snapshot; self._revision+=1
        self._sources=nxt
    def get_record_by_key(self,key): self._ensure_fresh(); return self._snapshot.records.get(key)
    def get_by_key(self,key):
        record=self.get_record_by_key(key); return record.entry if record else None
    def get_raw_by_key(self,key):
        record=self.get_record_by_key(key); return record.raw_entry if record else None
    def resolve_key(self,value):
        self._ensure_fresh(); direct=self._snapshot.records.get(value)
        if direct:return direct
        folded=self._snapshot.folded_keys.get(value.casefold())
        if folded:return self._snapshot.records.get(folded)
        compact=self._snapshot.compact_keys.get(compact_search_text(value)); return self._snapshot.records.get(compact) if compact else None
    def get_by_doi(self,value):
        self._ensure_fresh(); key=self._snapshot.dois.get(normalize_doi(value)); return self._snapshot.records.get(key) if key else None
    def is_secondary_only(self,key):
        record=self.get_record_by_key(key); return bool(record and record.in_secondary and not record.in_primary)
    def search(self,query,limit=20,scope:ReferenceScope="auto"): return [hit.entry for hit in self.search_hits(query,limit,scope)]
    def search_hits(self,query,limit=20,scope:ReferenceScope="auto"):
        self._ensure_fresh(); return [self._enrich_hit(hit) for hit in self._select_index(query,scope).search_hits(query,limit)]
    def _ensure_fresh(self): self.load() if not self._loaded else self.reload()
    @staticmethod
    def _signature(path):
        info=path.stat(); return f"{info.st_dev}:{info.st_ino}:{info.st_size}:{info.st_mtime_ns}:{info.st_ctime_ns}"
    def _read_source(self,path,previous,*,optional):
        path_key=str(path)
        try:
            signature=self._signature(path)
            if signature==previous.signature:return previous
            raw=path.read_text(encoding="utf-8")
            if signature!=self._signature(path):raise OSError("File changed during read")
            entries=previous.entries if raw==previous.raw else parse_references(raw); self._failures.pop(path_key,None); return _SourceSnapshot(signature,raw,entries)
        except Exception as exc:
            message=str(exc); absent_initially=not previous.raw and isinstance(exc,FileNotFoundError)
            if not (optional and absent_initially) and self._failures.get(path_key)!=message:self._warn(f"Bibliography reload retained previous data ({path}): {message}")
            self._failures[path_key]=message; return previous
    def _select_index(self,query,scope):
        if scope=="primary":return self._snapshot.primary
        if scope=="all":return self._snapshot.all
        if scope=="secondary":return self._snapshot.secondary
        if scope!="auto":raise ValueError(f"Unsupported reference scope: {scope}")
        return self._snapshot.all if looks_like_citation_key(query) or not self._snapshot.primary.has_plausible_match(query) else self._snapshot.ordinary
    def _enrich_hit(self,hit:SearchHit):
        key=str(hit.entry.get("citation-key") or hit.entry.get("id") or ""); record=self._snapshot.records.get(key)
        if record is None:raise RuntimeError(f"Search index returned unknown reference key: {key}")
        return ReferenceSearchHit(record.key,record.entry,record.raw_entry,hit.score,hit.match_basis,record.in_primary,record.in_secondary,record.in_secondary and not record.in_primary)
    def _build(self,sources):
        primary=list(sources[0].entries); secondary=list(sources[1].entries); primary_keys=frozenset(item.key for item in primary); secondary_by_key={item.key:item for item in secondary}; records={}
        for item in secondary:records[item.key]=ReferenceRecord(item.key,item.entry,item.raw_entry,False,True)
        for item in primary:records[item.key]=ReferenceRecord(item.key,item.entry,item.raw_entry,True,item.key in secondary_by_key)
        only=[item for item in secondary if item.key not in primary_keys]; now_ms=self._now(); primary_records=[records[item.key] for item in primary]; ordinary_records=primary_records+[records[item.key] for item in only if is_recent(item.raw_entry,now_ms,self.recent_days)]; all_records=primary_records+[records[item.key] for item in only]; secondary_records=[records[item.key] for item in secondary]
        folded={}; compact={}; dois={}
        for record in all_records:
            _add_unique_lookup(folded,record.key.casefold(),record.key); _add_unique_lookup(compact,compact_search_text(record.key),record.key); doi=normalize_doi(record.raw_entry.get("DOI") or record.raw_entry.get("doi"));
            if doi:_add_unique_lookup(dois,doi,record.key)
        return _CatalogSnapshot(BibliographyIndex.from_entries(item.entry for item in primary),BibliographyIndex.from_entries(r.entry for r in ordinary_records),BibliographyIndex.from_entries(r.entry for r in all_records),BibliographyIndex.from_entries(r.entry for r in secondary_records),primary_keys,records,folded,compact,dois,tuple(r.key for r in all_records))

def _add_unique_lookup(mapping,lookup,key):
    if not lookup:return
    previous=mapping.get(lookup)
    if previous is None and lookup not in mapping:mapping[lookup]=key
    elif previous!=key:mapping[lookup]=None
