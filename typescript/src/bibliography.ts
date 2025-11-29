import * as fs from 'fs/promises';
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
  // ... other fields
}

export class Bibliography {
  public entries: CslEntry[] = [];
  private jsonPath: string;

  constructor(jsonPath?: string) {
    this.jsonPath = jsonPath || 
      process.env.BIB_JSON || 
      path.join(os.homedir(), 'endnote', 'phd_biblio.json');
  }

  async load(): Promise<void> {
    const raw = await fs.readFile(this.jsonPath, 'utf-8');
    const data = JSON.parse(raw);
    this.entries = Array.isArray(data) ? data : (data.items || []);
  }

  search(query: string, limit: number = 20): CslEntry[] {
    if (!query) return this.entries.slice(0, limit);

    // Prepare options for fuzzysort to search specific fields
    // Note: For optimal performance with 6000 items, we might want to 
    // pre-calculate a 'searchString' property on load, similar to the Python version.
    const keys = ['title', 'id']; 
    
    // We create a simpler index for search to avoid complex object traversal during sort
    const simpleIndex = this.entries.map(e => ({
      obj: e,
      searchStr: `${this.getYear(e)} ${this.getAuthors(e)} ${e.title || ''} ${e.id}`
    }));

    const results = fuzzysort.go(query, simpleIndex, {
      key: 'searchStr',
      limit: limit,
      // threshold: -10000, 
      threshold: -Infinity,
    });

    return results.map(r => r.obj.obj);
  }

  private getAuthors(e: CslEntry): string {
    return e.author?.map(a => a.family).join(' ') || '';
  }

  private getYear(e: CslEntry): string {
    return e.issued?.['date-parts']?.[0]?.[0]?.toString() || '';
  }
}