import pytest
import json
import asyncio
from agent_tools.bibliography import Bibliography

@pytest.fixture
def mock_bib_file(tmp_path):
    data = {
        "items": [
            {
                "id": "async:test_1",
                "title": "Async Loading Test",
                "author": [{"family": "Loop", "given": "Event"}],
                "issued": {"date-parts": [[2024]]}
            }
        ]
    }
    f = tmp_path / "async_bib.json"
    with open(f, "w") as out:
        json.dump(data, out)
    return str(f)

@pytest.mark.asyncio
async def test_load_async_populates_entries(mock_bib_file):
    """Verify load_async correctly populates data without blocking."""
    bib = Bibliography(json_path=mock_bib_file)
    
    # Pre-condition: empty
    assert len(bib) == 0
    
    # Action: load asynchronously
    await bib.load_async()
    
    # Post-condition: populated
    assert len(bib) == 1
    results = bib.search("Async Loading")
    assert len(results) == 1
    assert results[0]["id"] == "async:test_1"

@pytest.mark.asyncio
async def test_load_async_missing_file():
    """Verify async loading handles missing files gracefully (same as sync)."""
    bib = Bibliography(json_path="/path/to/nowhere/ghost.json")
    await bib.load_async()
    assert len(bib) == 0