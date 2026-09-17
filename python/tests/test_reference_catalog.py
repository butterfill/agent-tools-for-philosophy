import json
from datetime import datetime, timezone

from agent_tools import ReferenceCatalog
from agent_tools.reference_catalog import is_recent, parse_references

NOW = datetime(2026, 7, 20, tzinfo=timezone.utc).timestamp() * 1000


def write(path, rows):
    path.write_text(json.dumps(rows), encoding="utf-8")


def test_source_policy_and_precedence(tmp_path):
    p = tmp_path / "primary.json"
    s = tmp_path / "secondary.json"
    write(
        p,
        [
            {"id": "shared:2020_mind", "type": "article", "title": "Primary Mind"},
            {"id": "mind:2000_old", "type": "article", "title": "Philosophy of Mind"},
        ],
    )
    write(
        s,
        [
            {"id": "shared:2020_mind", "type": "article", "title": "Wrong metadata"},
            {
                "id": "aru:2023_mind",
                "type": "article",
                "title": "ARU Mind",
                "accessed": {"date-parts": [[2026, 6, 1]]},
            },
            {"id": "remote:2025_topic", "type": "article", "title": "Unfindabletopic"},
            {
                "id": "recent:2026_mind",
                "type": "article",
                "title": "Recent Mind",
                "accessed": {"date-parts": [[2026, 7, 15]]},
            },
        ],
    )
    c = ReferenceCatalog(p, s, recent_days=14, now=lambda: NOW)
    assert c.ready
    assert len(c) == 2
    assert c.get_by_key("shared:2020_mind")["title"] == "Primary Mind"
    assert c.is_secondary_only("remote:2025_topic")
    ids = [e["id"] for e in c.search("mind", 10)]
    assert "recent:2026_mind" in ids and "aru:2023_mind" not in ids
    assert c.search("Unfindabletopic", 1)[0]["id"] == "remote:2025_topic"
    assert c.search("aru:2023_mind", 1)[0]["id"] == "aru:2023_mind"
    assert c.search("shared", 10, scope="secondary")[0]["title"] == "Primary Mind"


def test_keys_are_identities_and_doi_is_non_unique(tmp_path):
    p = tmp_path / "primary.json"
    s = tmp_path / "secondary.json"
    write(
        p,
        [
            {
                "citation-key": "Cullen:2014_individual",
                "type": "article",
                "DOI": "10.1000/ABC",
            },
            {
                "citation-key": "Cullen:2014_individuala",
                "type": "article",
                "DOI": "https://doi.org/10.1000/abc",
            },
            {
                "citation-key": "Other:2020_unique",
                "type": "article",
                "DOI": "10.1000/unique",
            },
        ],
    )
    c = ReferenceCatalog(p, s, warn=lambda _: None)
    c.load()
    assert c.resolve_key("cullen2014individual").key == "Cullen:2014_individual"
    assert [r.key for r in c.find_by_doi("doi:10.1000/abc")] == [
        "Cullen:2014_individual",
        "Cullen:2014_individuala",
    ]
    assert [r.key for r in c.find_by_doi("https://doi.org/10.1000/unique")] == [
        "Other:2020_unique"
    ]
    assert c.find_by_doi("10.1000/missing") == []


def test_readiness_uses_last_good_snapshot_not_current_file_state(tmp_path):
    p = tmp_path / "primary.json"
    s = tmp_path / "secondary.json"
    write(p, [{"id": "a:2020_x", "type": "article"}])
    c = ReferenceCatalog(p, s, warn=lambda _: None)
    assert c.ready
    p.unlink()
    assert c.ready
    assert c.keys() == ["a:2020_x"]

    missing = ReferenceCatalog(tmp_path / "never.json", s, warn=lambda _: None)
    assert not missing.ready


def test_last_good_and_optional_secondary(tmp_path):
    p = tmp_path / "primary.json"
    s = tmp_path / "secondary.json"
    write(p, [{"citation-key": "Cullen:2014_individual", "type": "article"}])
    c = ReferenceCatalog(p, s, warn=lambda _: None)
    c.load()
    p.write_text("{bad", encoding="utf-8")
    assert c.keys() == ["Cullen:2014_individual"]
    write(s, [{"id": "b:2021_y", "type": "article"}])
    assert "b:2021_y" in c.keys()


def test_parse_and_recent_strictness():
    e = parse_references(
        json.dumps(
            [
                {"citation-key": ":_americans", "id": "other"},
                {"id": 43138},
                {"id": 43138, "title": "duplicate"},
            ]
        )
    )
    assert [x.key for x in e] == [":_americans", "43138"]
    assert is_recent({"accessed": {"date-parts": [[2026, 7, 15]]}}, NOW, 14)
    assert not is_recent({"accessed": {"date-parts": [[2026, 2, 31]]}}, NOW, 14)
