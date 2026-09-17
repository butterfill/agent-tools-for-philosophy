import { AgentTools, ReferenceCatalog, type CslEntry, type ReferenceSearchHit } from '../src';
import { AgentTools as ClientAgentTools } from '../src/client'; import { ReferenceCatalog as CatalogImplementation } from '../src/reference-catalog';
describe('public package entry point', () => {
  it('exports AgentTools and ReferenceCatalog', () => { expect(AgentTools).toBe(ClientAgentTools); expect(ReferenceCatalog).toBe(CatalogImplementation); });
  it('exports catalogue types', () => { const entry: CslEntry = { id: 'example:key', type: 'article-journal' }; const hit = {} as ReferenceSearchHit; expect(entry.id).toBe('example:key'); expect(hit).toBeDefined(); });
});
