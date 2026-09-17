import os
from pathlib import Path
import pytest
from agent_tools import ReferenceCatalog

def test_e2e_production_search():
    primary=Path(os.environ.get('BIB_JSON') or Path.home()/'endnote'/'phd_biblio.json')
    if not primary.exists():
        if os.environ.get('BIB_JSON'): pytest.fail(f'BIB_JSON is set to {primary} but the file does not exist')
        pytest.skip('No production bibliography found')
    c=ReferenceCatalog(); c.load(); results=c.search('davidson 1963'); assert results; assert 'davidson' in str(results[0]).casefold() or '1963' in str(results[0])
