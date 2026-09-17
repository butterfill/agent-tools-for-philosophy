import json, pytest
from agent_tools import ReferenceCatalog
@pytest.fixture
def mock_bib_file(tmp_path):
    p=tmp_path/'async_bib.json'; p.write_text(json.dumps({'items':[{'id':'async:test_1','title':'Async Loading Test','author':[{'family':'Loop'}],'issued':{'date-parts':[[2024]]}}]}),encoding='utf-8'); return p
@pytest.mark.asyncio
async def test_load_async_populates_catalog(mock_bib_file,tmp_path):
    c=ReferenceCatalog(mock_bib_file,tmp_path/'missing-secondary.json'); await c.load_async(); assert len(c)==1; assert c.search('Async Loading')[0]['id']=='async:test_1'
@pytest.mark.asyncio
async def test_load_async_missing_primary_is_error(tmp_path):
    c=ReferenceCatalog(tmp_path/'missing-primary.json',tmp_path/'missing-secondary.json',warn=lambda _:None)
    with pytest.raises(ValueError,match='Primary bibliography unavailable'): await c.load_async()
