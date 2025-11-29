import { AgentTools } from '../src/client';

describe('AgentTools Client', () => {
  test('instantiation works', () => {
    const tools = new AgentTools();
    expect(tools).toBeDefined();
  });

  // Optional: Mock child_process to verify commands are constructed correctly
  // without actually running the shell scripts.
});