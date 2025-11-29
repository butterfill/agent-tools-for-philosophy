import json
import pytest
import os
from pathlib import Path
from agent_tools.bibliography import Bibliography

# Locate the fixture relative to this test file
FIXTURE_PATH = Path(__file__).parents[2] / "tests" / "fixtures" / "search_corpus.json"

@pytest.fixture
def corpus_data():
    with open(FIXTURE_PATH, "r") as f:
        return json.load(f)

@pytest.fixture
def bib_instance(corpus_data, tmp_path):
    # Write the mock dataset to a temp file so Bibliography can load it
    db_path = tmp_path / "mock_bib.json"
    with open(db_path, "w") as f:
        json.dump(corpus_data["dataset"], f)
    
    bib = Bibliography(json_path=str(db_path))
    bib.load()
    return bib

def test_shared_search_corpus(bib_instance, corpus_data):
    """
    Iterates through the shared corpus and verifies Python logic matches expectations.
    """
    for case in corpus_data["test_cases"]:
        query = case["query"]
        expected_ids = case["must_include"]
        description = case["description"]

        results = bib_instance.search(query, limit=5)
        result_ids = [r["id"] for r in results]

        for expected in expected_ids:
            assert expected in result_ids, (
                f"Failed case '{description}': Query '{query}' did not find '{expected}'. "
                f"Found: {result_ids}"
            )

def test_client_smoke():
    """Basic import check for the client."""
    from agent_tools.client import AgentTools
    client = AgentTools()
    assert client is not None