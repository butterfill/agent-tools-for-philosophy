import { chmod, mkdtemp, rm, writeFile } from 'fs/promises';
import * as os from 'os';
import * as path from 'path';
import { AgentTools, ToolExecutionError } from '../src/client';

describe('AgentTools Client', () => {
  const originalPath = process.env.PATH;
  const originalTestMdPath = process.env.TEST_MD_PATH;
  let tempDir: string;

  beforeEach(async () => {
    tempDir = await mkdtemp(path.join(os.tmpdir(), 'agent-tools-client-'));
    process.env.PATH = `${tempDir}${path.delimiter}${originalPath || ''}`;
  });

  afterEach(async () => {
    process.env.PATH = originalPath;
    if (originalTestMdPath === undefined) delete process.env.TEST_MD_PATH;
    else process.env.TEST_MD_PATH = originalTestMdPath;
    await rm(tempDir, { recursive: true, force: true });
  });

  async function writeExecutable(name: string, content: string): Promise<string> {
    const target = path.join(tempDir, name);
    await writeFile(target, content, 'utf8');
    await chmod(target, 0o755);
    return target;
  }

  test('instantiation works', () => {
    const tools = new AgentTools();
    expect(tools).toBeDefined();
  });

  test('getMdContent resolves the Markdown path and reads the file verbatim', async () => {
    const sourcePath = path.join(tempDir, 'source with spaces.md');
    const source = '  leading whitespace\nbody\ntrailing whitespace  \n';
    await writeFile(sourcePath, source, 'utf8');
    process.env.TEST_MD_PATH = sourcePath;
    await writeExecutable('cite2md', `#!/usr/bin/env bash\nset -euo pipefail\nif [[ "\${1:-}" == "--cat" ]]; then\n  echo "unexpected --cat" >&2\n  exit 9\nfi\nprintf '%s\\n' "$TEST_MD_PATH"\n`);

    await expect(new AgentTools().getMdContent('test:key')).resolves.toBe(source);
  });

  test('command capture allows output larger than Node execFile default maxBuffer', async () => {
    await writeExecutable('cite2pdf', `#!/usr/bin/env node\nprocess.stdout.write('x'.repeat(2 * 1024 * 1024));\n`);

    const value = await new AgentTools().getPdfPath('test:key');
    expect(value).not.toBeNull();
    expect(value).toHaveLength(2 * 1024 * 1024);
  });

  test('reports string-valued process errors instead of exit=unknown', async () => {
    const target = path.join(tempDir, 'cite2pdf');
    await writeFile(target, '#!/usr/bin/env bash\nexit 0\n', 'utf8');
    await chmod(target, 0o644);
    process.env.PATH = tempDir;

    try {
      await new AgentTools().getPdfPath('test:key');
      throw new Error('expected getPdfPath to fail');
    } catch (error) {
      expect(error).toBeInstanceOf(ToolExecutionError);
      const executionError = error as ToolExecutionError;
      expect(executionError.exitCode).toBeNull();
      expect(executionError.errorCode).toBe('EACCES');
      expect(executionError.message).toContain('code=EACCES');
      expect(executionError.message).not.toContain('exit=unknown');
    }
  });
});
