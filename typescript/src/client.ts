import { spawn, execFile } from 'child_process';
import { promisify } from 'util';

const execFileAsync = promisify(execFile);

export interface ActionResult {
  ok: boolean;
  error?: string;
}

export class AgentTools {
  private env: NodeJS.ProcessEnv;

  constructor(papersDir?: string) {
    this.env = { ...process.env };
    if (papersDir) {
      this.env.PAPERS_DIR = papersDir;
    }
  }

  private async run(cmd: string, args: string[]): Promise<string | null> {
    try {
      const { stdout } = await execFileAsync(cmd, args, { env: this.env });
      return stdout.trim() || null;
    } catch (e) {
      return null;
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
    return this.run('cite2md', ['--cat', key]);
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
}
