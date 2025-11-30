import * as fs from 'fs';
import * as path from 'path';
import * as os from 'os';
import fuzzysort from 'fuzzysort';

// Basic type interface for CSL-JSON
export interface CslEntry {
  id: string;
  type: string;
  title?: string;
  author?: { family?: string; given?: string }[];
  issued?: { 'date-parts'?: (number | string)[][] };
  [key: string]: any;
}

export class Bibliography {
  public entries: CslEntry[] = [];
  private jsonPath: string;
  // Index structure for fuzzysort: wraps entry and the search string
  private searchIndex: { obj: CslEntry, searchStr: string }[] = [];

  constructor(jsonPath?: string) {
    this.jsonPath = jsonPath || 
      process.env.BIB_JSON || 
      path.join(os.homedir(), 'endnote', 'phd_biblio.json');
    // Note: constructor no longer loads automatically to avoid blocking
  }

  get length(): number {
    return this.entries.length;
  }

  async load(): Promise<void> {
    try {
      await fs.promises.access(this.jsonPath, fs.constants.F_OK);
    } catch {
      this.entries = [];
      this.searchIndex = [];
      return;
    }

    try {
      const raw = await fs.promises.readFile(this.jsonPath, 'utf-8');
      const data = JSON.parse(raw);
      this.entries = Array.isArray(data) ? data : (data.items || []);
    } catch (error) {
      console.error(`Error loading bibliography from ${this.jsonPath}:`, error);
      this.entries = [];
    }
    
    // Prepare index for search
    this.searchIndex = this.entries.map(e => ({
      obj: e,
      // Replicate the robust corpus construction from Python
      // explicitly handles missing title/id and ensures string concatenation
      searchStr: `${this.getYear(e)} ${this.getAuthors(e)} ${e.title || ''} ${e.id || ''}`
    }));
  }

  search(query: string, limit: number = 20): CslEntry[] {
    if (this.entries.length === 0) return [];
    if (!query) return this.entries.slice(0, limit);

    const results = fuzzysort.go(query, this.searchIndex, {
      key: 'searchStr',
      limit: limit,
      threshold: -Infinity,
    });

    return results.map(r => r.obj.obj);
  }

  private getAuthors(e: CslEntry): string {
    // Robust check: match Python's isinstance(authors, list) check
    // This prevents crashes if "author" is null, or a string, or an object in malformed JSON
    if (!Array.isArray(e.author)) {
      return '';
    }
    return e.author
      .map(a => a?.family || '') // Handle potentially missing family keys safely
      .join(' ');
  }

  private getYear(e: CslEntry): string {
    // Robust parsing matching Python logic
    try {
      const parts = e.issued?.['date-parts'];
      if (parts && Array.isArray(parts) && parts.length > 0) {
        const first = parts[0];
        if (Array.isArray(first) && first.length > 0) {
          return String(first[0]);
        }
      }
    } catch {
      // ignore errors
    }
    return '';
  }
}