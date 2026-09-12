import { AgentTools, Bibliography, type CslEntry } from '../src';
import { AgentTools as ClientAgentTools } from '../src/client';
import { Bibliography as BibliographyImplementation } from '../src/bibliography';

describe('public package entry point', () => {
  it('exports the documented runtime classes from the root module', () => {
    expect(AgentTools).toBe(ClientAgentTools);
    expect(Bibliography).toBe(BibliographyImplementation);
  });

  it('exports bibliography types from the root module', () => {
    const entry: CslEntry = { id: 'example:key', type: 'article-journal' };
    expect(entry.id).toBe('example:key');
  });
});
