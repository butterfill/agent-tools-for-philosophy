import json

import pytest

from agent_tools import ReferenceCatalog


@pytest.fixture
def mock_bib_file(tmp_path):
    path = tmp_path / "async_bib.json"
    path.write_text(
        json.dumps(
            {
                "items": [
                    {
                        "id": "async:test_1",
                        "title": "Async Loading Test",
                        "author": [{"family": "Loop"}],
                        "issued": {"date-parts": [[2024]]},
                    }
                ]
            }
        ),
        encoding="utf-8",
    )
    return path


@pytest.mark.asyncio
async def test_load_async_populates_catalog(mock_bib_file, tmp_path):
    catalog = ReferenceCatalog(mock_bib_file, tmp_path / "missing-secondary.json")
    await catalog.load_async()
    assert len(catalog) == 1
    assert catalog.search("Async Loading")[0]["id"] == "async:test_1"


@pytest.mark.asyncio
async def test_missing_primary_remains_an_error_until_it_recovers(tmp_path):
    primary = tmp_path / "missing-primary.json"
    catalog = ReferenceCatalog(
        primary,
        tmp_path / "missing-secondary.json",
        warn=lambda _: None,
    )

    with pytest.raises(ValueError, match="Primary bibliography unavailable"):
        await catalog.load_async()
    with pytest.raises(ValueError, match="Primary bibliography unavailable"):
        catalog.search("anything")

    primary.write_text(json.dumps([{"id": "recovered:2026_source"}]), encoding="utf-8")
    assert catalog.search("recovered", 1)[0]["id"] == "recovered:2026_source"
