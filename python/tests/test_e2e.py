import os
import pytest
from agent_tools.bibliography import Bibliography

def test_e2e_production_search():
    """
    Verifies that the Bibliography class correctly loads the real production file
    (specified via BIB_JSON or default) and finds a known record.
    """
    bib = Bibliography()
    bib.load()

    # If the bibliography is empty, we need to determine if that's a failure or a skip.
    if len(bib) == 0:
        # If BIB_JSON was explicitly set, this is a failure (wrong path or bad format).
        if os.environ.get("BIB_JSON"):
            pytest.fail(f"BIB_JSON is set to {os.environ['BIB_JSON']} but no entries were loaded.")
        
        # If the default file exists but failed to load, that's also a failure.
        default_path = os.path.expanduser("~/endnote/phd_biblio.json")
        if os.path.exists(default_path):
             pytest.fail(f"Default bibliography found at {default_path} but no entries were loaded.")

        # Otherwise, we are likely in a CI environment without the prod file.
        pytest.skip("No production bibliography found to test against.")

    # Perform the known query
    query = "davidson 1963"
    results = bib.search(query)

    # Assertions
    assert len(results) > 0, f"Search for '{query}' returned 0 results in production bibliography."
    
    # Optional: Debug output if needed
    first_result = results[0]
    print(f"Found: {first_result.get('id', 'unknown')}")