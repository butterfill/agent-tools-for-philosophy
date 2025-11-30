import { AgentTools } from '../src/client';

let nextStdout = '';

jest.mock('util', () => {
  return {
    promisify: (_fn: any) => async (_cmd: string, _args: string[], _opts: any) => {
      return { stdout: nextStdout } as any;
    }
  };
});

describe('AgentTools.rgSources', () => {
  test('returns raw stdout or null via wrapper', async () => {
    nextStdout = 'line1\nline2\n';
    const tools = new AgentTools();
    const raw = await tools.rgSources(['-n', 'pattern']);
    expect(raw).toBe('line1\nline2');
  });

  test('lines helper splits and trims only trailing newline', async () => {
    nextStdout = 'a\n b \n';
    const tools = new AgentTools();
    const lines = await tools.rgSourcesLines(['-l', 'foo']);
    expect(lines).toEqual(['a', ' b ']);
  });

  test('empty output produces null/[]', async () => {
    nextStdout = '';
    const tools = new AgentTools();
    const raw = await tools.rgSources(['-n', 'foo']);
    const lines = await tools.rgSourcesLines(['-n', 'foo']);
    expect(raw).toBeNull();
    expect(lines).toEqual([]);
  });
});
