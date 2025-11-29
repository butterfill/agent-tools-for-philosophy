import json
import os
from rapidfuzz import process, fuzz, utils

class Bibliography:
    def __init__(self, json_path: str = None):
        self.path = json_path or os.environ.get("BIB_JSON", os.path.expanduser("~/endnote/phd_biblio.json"))
        self.entries = []
        self._search_corpus = []

    def load(self):
        with open(self.path, 'r', encoding='utf-8') as f:
            data = json.load(f)
            self.entries = data.get('items', data) if isinstance(data, dict) else data
        
        # Prepare corpus for RapidFuzz
        self._search_corpus = []
        for e in self.entries:
            # Logic to combine Year + Author + Title into a string
            # (See previous artifacts for full logic)
            parts = [
                str(e.get('issued', {}).get('date-parts', [[k for k in []]])[0][0]) if 'issued' in e else "",
                " ".join([a.get('family','') for a in e.get('author', [])]),
                e.get('title', ''),
                e.get('id', '')
            ]
            self._search_corpus.append(" ".join(parts))

    def search(self, query: str, limit: int = 20):
        if not query: return self.entries[:limit]
        results = process.extract(
            query, self._search_corpus, limit=limit, scorer=fuzz.partial_ratio
        )
        return [self.entries[idx] for _, _, idx in results]