import { AgentTools } from '../src/client';

// We'll mock util.promisify so that execFileAsync returns our controlled stdout
let nextStdout = '';

jest.mock('util', () => {
  return {
    promisify: (_fn: any) => async (_cmd: string, _args: string[], _opts: any) => {
      return { stdout: nextStdout } as any;
    }
  };
});

describe('AgentTools.getKeysFromDraft', () => {
  test('parses newline-delimited keys and trims/filters', async () => {
    nextStdout = 'alpha\n beta\r\n  \n gamma ';
    const tools = new AgentTools();
    const keys = await tools.getKeysFromDraft('/tmp/draft.md');
    expect(keys).toEqual(['alpha', 'beta', 'gamma']);
  });

  test('returns empty array when command yields no output', async () => {
    nextStdout = '';
    const tools = new AgentTools();
    const keys = await tools.getKeysFromDraft('/tmp/draft.md');
    expect(keys).toEqual([]);
  });
});
