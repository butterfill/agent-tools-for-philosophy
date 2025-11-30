import json
import os
from rapidfuzz import process, fuzz, utils

class Bibliography:
    def __init__(self, json_path: str = None):
        self.path = json_path or os.environ.get("BIB_JSON", os.path.expanduser("~/endnote/phd_biblio.json"))
        self.entries = []
        self._search_corpus = []
        # Automatically load data on initialization
        self.load()

    def __len__(self):
        return len(self.entries)

    def load(self):
        if not os.path.exists(self.path):
            return

        with open(self.path, 'r', encoding='utf-8') as f:
            data = json.load(f)
            self.entries = data.get('items', data) if isinstance(data, dict) else data
        
        # Prepare corpus for RapidFuzz
        self._search_corpus = []
        for e in self.entries:
            # Robustly extract year from CSL-JSON structure
            year = ""
            try:
                issued = e.get('issued')
                if issued:
                    date_parts = issued.get('date-parts')
                    # Expect list of lists: [[2018, 1, 1]] or [[2018]]
                    if date_parts and isinstance(date_parts, list) and len(date_parts) > 0:
                        first_part = date_parts[0]
                        if isinstance(first_part, list) and len(first_part) > 0:
                            year = str(first_part[0])
            except Exception:
                pass

            # Handle author field safely (it can be None in JSON)
            authors_list = e.get('author')
            if isinstance(authors_list, list):
                authors_str = " ".join([a.get('family', '') for a in authors_list if isinstance(a, dict)])
            else:
                authors_str = ""

            # Ensure all parts are strings before joining
            parts = [
                year,
                authors_str,
                str(e.get('title') or ''),
                str(e.get('id') or '')
            ]
            self._search_corpus.append(" ".join(parts))

    def search(self, query: str, limit: int = 20):
        if not self.entries:
            return []
        if not query: return self.entries[:limit]
        
        results = process.extract(
            query, self._search_corpus, limit=limit, scorer=fuzz.partial_ratio
        )
        return [self.entries[idx] for _, _, idx in results]