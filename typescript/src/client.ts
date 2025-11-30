import { spawn, execFile } from 'child_process';
import { promisify } from 'util';

const execFileAsync = promisify(execFile);

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

  openVsCode(key: string): void {
    spawn('cite2md', ['--vs', key], { env: this.env, detached: true, stdio: 'ignore' }).unref();
  }

  openVsCodeInsiders(key: string): void {
    spawn('cite2md', ['--vsi', key], { env: this.env, detached: true, stdio: 'ignore' }).unref();
  }

  revealMd(key: string): void {
    spawn('cite2md', ['--reveal', key], { env: this.env, detached: true, stdio: 'ignore' }).unref();
  }
  
  openPdf(key: string): void {
    spawn('cite2pdf', ['--open', key], { env: this.env, detached: true, stdio: 'ignore' }).unref();
  }

  revealPdf(key: string): void {
    spawn('cite2pdf', ['--reveal', key], { env: this.env, detached: true, stdio: 'ignore' }).unref();
  }
}