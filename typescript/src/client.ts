import { spawn, execFile } from 'child_process';
import { readFile } from 'fs/promises';
import { promisify } from 'util';

const execFileAsync = promisify(execFile);
const EXEC_FILE_MAX_BUFFER = 64 * 1024 * 1024;

export interface ActionResult {
  ok: boolean;
  error?: string;
}

export class ToolNotFoundError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'ToolNotFoundError';
  }
}

export class ToolExecutionError extends Error {
  public exitCode: number | null;
  public stderr?: string;
  public errorCode?: string;
  constructor(message: string, exitCode: number | null, stderr?: string, errorCode?: string) {
    super(message);
    this.name = 'ToolExecutionError';
    this.exitCode = exitCode;
    this.stderr = stderr;
    this.errorCode = errorCode;
  }
}

export class AgentTools {
  private env: NodeJS.ProcessEnv;

  constructor(papersDir?: string) {
    this.env = { ...process.env };
    if (papersDir) {
      this.env.PAPERS_DIR = papersDir;
    }
  }

  private executionError(cmd: string, args: string[], error: any): Error {
    if (error?.code === 'ENOENT') {
      return new ToolNotFoundError(`Executable not found: ${cmd}`);
    }
    const stderr = typeof error?.stderr === 'string'
      ? error.stderr
      : error?.stderr == null ? undefined : String(error.stderr);
    const exitCode = typeof error?.code === 'number' ? error.code : null;
    const errorCode = typeof error?.code === 'string' ? error.code : undefined;
    const status = exitCode != null
      ? `exit=${exitCode}`
      : errorCode ? `code=${errorCode}` : 'exit=unknown';
    const msg = `Command failed: ${cmd} ${args.join(' ')} (${status})` + (stderr ? `\n${stderr}` : '');
    return new ToolExecutionError(msg, exitCode, stderr, errorCode);
  }

  private async run(cmd: string, args: string[]): Promise<string | null> {
    try {
      const { stdout } = await execFileAsync(cmd, args, { env: this.env, maxBuffer: EXEC_FILE_MAX_BUFFER });
      return (stdout?.trim() || '') || null;
    } catch (error: any) {
      throw this.executionError(cmd, args, error);
    }
  }

  private async runRaw(cmd: string, args: string[]): Promise<string | null> {
    try {
      const { stdout } = await execFileAsync(cmd, args, { env: this.env, maxBuffer: EXEC_FILE_MAX_BUFFER });
      // Do not trim spaces; only normalize to null if completely empty
      if (stdout == null) return null;
      const s = String(stdout);
      return s.length > 0 ? s : null;
    } catch (error: any) {
      throw this.executionError(cmd, args, error);
    }
  }

  private async spawnAction(cmd: string, args: string[]): Promise<ActionResult> {
    try {
      const child = spawn(cmd, args, { env: this.env, detached: true, stdio: 'ignore' });
      return await new Promise<ActionResult>((resolve) => {
        let settled = false;
        child.on('error', (err) => {
          if (!settled) {
            settled = true;
            resolve({ ok: false, error: (err as Error)?.message || String(err) });
          }
        });
        setImmediate(() => {
          if (!settled) {
            try { child.unref(); } catch {}
            settled = true;
            resolve({ ok: true });
          }
        });
      });
    } catch (e) {
      return { ok: false, error: (e as Error)?.message || String(e) };
    }
  }

  async getMdPath(key: string): Promise<string | null> {
    return this.run('cite2md', [key]);
  }

  async getPdfPath(key: string): Promise<string | null> {
    return this.run('cite2pdf', [key]);
  }

  async getMdContent(key: string): Promise<string | null> {
    const mdPath = await this.getMdPath(key);
    if (!mdPath) return null;
    return readFile(mdPath, 'utf8');
  }
  
  async getBibEntry(key: string): Promise<string | null> {
    return this.run('cite2bib', [key]);
  }

  openVsCode(key: string): Promise<ActionResult> {
    return this.spawnAction('cite2md', ['--vs', key]);
  }

  openVsCodeInsiders(key: string): Promise<ActionResult> {
    return this.spawnAction('cite2md', ['--vsi', key]);
  }

  revealMd(key: string): Promise<ActionResult> {
    return this.spawnAction('cite2md', ['--reveal', key]);
  }
  
  openPdf(key: string): Promise<ActionResult> {
    return this.spawnAction('cite2pdf', ['--open', key]);
  }

  revealPdf(key: string): Promise<ActionResult> {
    return this.spawnAction('cite2pdf', ['--reveal', key]);
  }

  async getKeysFromDraft(draftPath: string): Promise<string[]> {
    const output = await this.run('draft2keys', [draftPath]);
    if (!output) return [];
    // Handle normalization of newlines that raw execFile output contains
    return output.split(/\r?\n/).map(s => s.trim()).filter(Boolean);
  }

  async rgSources(args: string[]): Promise<string | null> {
    const out = await this.runRaw('rg-sources', args);
    if (out == null) return null;
    // Remove a single trailing newline (CRLF or LF) without trimming spaces
    if (out.endsWith('\r\n')) return out.slice(0, -2);
    if (out.endsWith('\n') || out.endsWith('\r')) return out.slice(0, -1);
    return out;
  }

  async rgSourcesLines(args: string[]): Promise<string[]> {
    const output = await this.rgSources(args);
    if (!output) return [];
    return output.split(/\n/);
  }
}
