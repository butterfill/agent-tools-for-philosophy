import json
from pathlib import Path
import pytest
from agent_tools.bibliography import BibliographyIndex
FIXTURE_PATH=Path(__file__).parents[2]/'tests'/'fixtures'/'search_corpus.json'
@pytest.fixture
def corpus_data():
    with open(FIXTURE_PATH,encoding='utf-8') as f:return json.load(f)

def test_shared_search_corpus(corpus_data):
    bib=BibliographyIndex.from_entries(corpus_data['dataset'])
    for case in corpus_data['test_cases']:
        ids=[r['id'] for r in bib.search(case['query'],5)]
        for expected in case['must_include']: assert expected in ids
        if case.get('expected_first'): assert ids[0]==case['expected_first']

def test_client_smoke():
    from agent_tools.client import AgentTools
    assert AgentTools() is not None
