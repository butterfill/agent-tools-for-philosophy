import { readFile, stat } from 'node:fs/promises';
import { homedir } from 'node:os';
import { join } from 'node:path';
import { BibliographyIndex, compactSearchText, type CslEntry, type SearchHit } from './bibliography';

export type ReferenceScope = 'auto' | 'primary' | 'all' | 'secondary';

export interface ReferenceRecord {
  key: string;
  entry: CslEntry;
  rawEntry: CslEntry;
  inPrimary: boolean;
  inSecondary: boolean;
}

export interface ReferenceSearchHit {
  key: string;
  entry: CslEntry;
  rawEntry: CslEntry;
  score: number;
  matchBasis: string[];
  inPrimary: boolean;
  inSecondary: boolean;
  secondaryOnly: boolean;
}

export interface CatalogOptions {
  primaryPath?: string;
  secondaryPath?: string;
  recentDays?: number;
  pollMs?: number;
  now?: () => number;
  warn?: (message: string) => void;
}

interface SourceEntry { key: string; rawEntry: CslEntry; entry: CslEntry; }
interface SourceSnapshot { signature: string; raw: string; entries: SourceEntry[]; }
interface CatalogSnapshot {
  primary: BibliographyIndex;
  ordinary: BibliographyIndex;
  all: BibliographyIndex;
  secondary: BibliographyIndex;
  primaryKeys: Set<string>;
  records: Map<string, ReferenceRecord>;
  foldedKeys: Map<string, string | null>;
  compactKeys: Map<string, string | null>;
  dois: Map<string, string | null>;
  orderedKeys: string[];
}

export function looksLikeCitationKey(query: string): boolean { return /^[^\s:]+:?\d{4}_\S+$/u.test(query); }

/** Accept CSL arrays and { items } containers; never mistake corruption for empty. */
export function parseReferences(raw: string): SourceEntry[] {
  const data: unknown = JSON.parse(raw);
  const rows = Array.isArray(data) ? data : data && typeof data === 'object' && 'items' in data ? (data as { items?: unknown }).items : null;
  if (!Array.isArray(rows)) throw new Error('Expected a CSL-JSON array or { items: [] }');
  const entries = new Map<string, SourceEntry>();
  for (const row of rows) {
    if (!row || typeof row !== 'object' || Array.isArray(row)) continue;
    const item = row as CslEntry;
    const keyValue = item['citation-key'] || item.id;
    if (typeof keyValue !== 'string' && typeof keyValue !== 'number') continue;
    const key = String(keyValue).trim();
    if (!key || entries.has(key)) continue;
    const rawEntry = { ...item };
    entries.set(key, { key, rawEntry, entry: { ...rawEntry, id: key, 'citation-key': key } });
  }
  if (rows.length && !entries.size) throw new Error('No usable citation keys in nonempty source');
  return [...entries.values()];
}

export function isRecent(entry: CslEntry, now: number, days: number): boolean {
  const parts = entry.accessed?.['date-parts']?.[0];
  if (!Array.isArray(parts) || parts.length < 3) return false;
  if (!parts.slice(0, 3).every(value => typeof value === 'number' || (typeof value === 'string' && /^\d+$/.test(value)))) return false;
  const [year, month, day] = parts.map(Number);
  if (![year, month, day].every(Number.isInteger) || year < 1000 || month < 1 || month > 12 || day < 1 || day > 31) return false;
  const date = new Date(Date.UTC(year, month - 1, day));
  if (date.getUTCFullYear() !== year || date.getUTCMonth() !== month - 1 || date.getUTCDate() !== day) return false;
  const age = now - date.getTime();
  return age >= 0 && age <= days * 86_400_000;
}

export function normalizeDoi(value: unknown): string {
  return String(value || '').trim().replace(/^doi\s*:\s*/i, '').replace(/^https?:\/\/(?:dx\.)?doi\.org\//i, '').trim().toLowerCase();
}

export class ReferenceCatalog {
  private sources: SourceSnapshot[] = [this.emptySource(), this.emptySource()];
  private snapshot: CatalogSnapshot;
  private timer: ReturnType<typeof setTimeout> | undefined;
  private pending: Promise<void> | undefined;
  private closed = false;
  private failures = new Map<string, string>();
  private revisionValue = 0;
  private readonly paths: [string, string];
  private readonly recentDaysValue: number;

  constructor(private readonly options: CatalogOptions = {}) {
    this.paths = [
      options.primaryPath || process.env.BIB_JSON || join(homedir(), 'endnote', 'phd_biblio.json'),
      options.secondaryPath || process.env.ZOTERO_JSON || join(homedir(), 'endnote', 'zotero-export.json'),
    ];
    const envRecent = process.env.ZOTERO_RECENT_DAYS;
    this.recentDaysValue = options.recentDays ?? (envRecent ? Number(envRecent) : 14);
    if (!Number.isFinite(this.recentDaysValue) || this.recentDaysValue < 0) throw new Error('recentDays must be non-negative');
    this.snapshot = this.build(this.sources);
  }

  private emptySource(): SourceSnapshot { return { signature: '', raw: '', entries: [] }; }
  get revision(): number { return this.revisionValue; }
  get length(): number { return this.snapshot.primary.length; }
  get primaryPath(): string { return this.paths[0]; }
  get secondaryPath(): string { return this.paths[1]; }
  get recentDays(): number { return this.recentDaysValue; }
  keys(): string[] { return this.snapshot.orderedKeys.slice(); }
  getRecordByKey(key: string): ReferenceRecord | undefined { return this.snapshot.records.get(key); }
  getByKey(key: string): CslEntry | undefined { return this.getRecordByKey(key)?.entry; }
  getRawByKey(key: string): CslEntry | undefined { return this.getRecordByKey(key)?.rawEntry; }

  resolveKey(value: string): ReferenceRecord | undefined {
    const direct = this.snapshot.records.get(value);
    if (direct) return direct;
    const foldedKey = this.snapshot.foldedKeys.get(value.toLowerCase());
    if (foldedKey) return this.snapshot.records.get(foldedKey);
    const compact = this.snapshot.compactKeys.get(compactSearchText(value));
    return compact ? this.snapshot.records.get(compact) : undefined;
  }

  getByDoi(value: string): ReferenceRecord | undefined {
    const key = this.snapshot.dois.get(normalizeDoi(value));
    return key ? this.snapshot.records.get(key) : undefined;
  }

  isSecondaryOnly(key: string): boolean {
    const record = this.snapshot.records.get(key);
    return Boolean(record?.inSecondary && !record.inPrimary);
  }

  search(query: string, limit = 20, scope: ReferenceScope = 'auto'): CslEntry[] {
    return this.searchHits(query, limit, scope).map(hit => hit.entry);
  }

  searchHits(query: string, limit = 20, scope: ReferenceScope = 'auto'): ReferenceSearchHit[] {
    const index = this.selectIndex(query, scope);
    return index.searchHits(query, limit).map(hit => this.enrichHit(hit));
  }

  private selectIndex(query: string, scope: ReferenceScope): BibliographyIndex {
    const snapshot = this.snapshot;
    switch (scope) {
      case 'primary': return snapshot.primary;
      case 'all': return snapshot.all;
      case 'secondary': return snapshot.secondary;
      case 'auto': return looksLikeCitationKey(query) || !snapshot.primary.hasPlausibleMatch(query) ? snapshot.all : snapshot.ordinary;
    }
  }

  private enrichHit(hit: SearchHit): ReferenceSearchHit {
    const key = String(hit.entry['citation-key'] || hit.entry.id || '');
    const record = this.snapshot.records.get(key);
    if (!record) throw new Error(`Search index returned unknown reference key: ${key}`);
    return { key: record.key, entry: record.entry, rawEntry: record.rawEntry, score: hit.score, matchBasis: hit.matchBasis,
      inPrimary: record.inPrimary, inSecondary: record.inSecondary, secondaryOnly: record.inSecondary && !record.inPrimary };
  }

  async start(): Promise<void> {
    await this.reload();
    const primaryPath = this.paths[0];
    if (!this.sources[0].signature) {
      const reason = this.failures.get(primaryPath) || 'no usable primary snapshot';
      throw new Error(`Primary bibliography unavailable (${primaryPath}): ${reason}`);
    }
    this.schedule();
  }

  close(): void { this.closed = true; if (this.timer) clearTimeout(this.timer); this.timer = undefined; }
  reload(): Promise<void> {
    if (this.closed) return Promise.resolve();
    if (!this.pending) this.pending = this.refresh().finally(() => { this.pending = undefined; });
    return this.pending;
  }

  private schedule(): void {
    if (this.closed || this.timer) return;
    this.timer = setTimeout(() => { this.timer = undefined; void this.reload().finally(() => this.schedule()); }, this.options.pollMs ?? 2000);
    this.timer.unref();
  }

  private async signature(path: string): Promise<string> {
    const info = await stat(path, { bigint: true });
    return `${info.dev}:${info.ino}:${info.size}:${info.mtimeNs}:${info.ctimeNs}`;
  }

  private async refresh(): Promise<void> {
    const next = await Promise.all(this.paths.map(async (path, index) => {
      const previous = this.sources[index];
      try {
        const signature = await this.signature(path);
        if (signature === previous.signature) return previous;
        const raw = await readFile(path, 'utf8');
        if (signature !== await this.signature(path)) throw new Error('File changed during read');
        const entries = raw === previous.raw ? previous.entries : parseReferences(raw);
        this.failures.delete(path);
        return { signature, raw, entries };
      } catch (error) {
        const message = error instanceof Error ? error.message : String(error);
        const absentInitially = !previous.raw && (error as NodeJS.ErrnoException).code === 'ENOENT';
        if (!absentInitially && this.failures.get(path) !== message) (this.options.warn || console.warn)(`Bibliography reload retained previous data (${path}): ${message}`);
        this.failures.set(path, message);
        return previous;
      }
    })) as [SourceSnapshot, SourceSnapshot];
    if (this.closed) return;
    if (next.some((source, index) => source.raw !== this.sources[index].raw)) {
      try { this.snapshot = this.build(next); this.revisionValue += 1; }
      catch (error) { (this.options.warn || console.warn)(`Bibliography index reload failed: ${String(error)}`); return; }
    }
    this.sources = next;
  }

  private build(sources: SourceSnapshot[]): CatalogSnapshot {
    const primary = sources[0].entries; const secondary = sources[1].entries;
    const primaryKeys = new Set(primary.map(item => item.key));
    const secondaryByKey = new Map(secondary.map(item => [item.key, item]));
    const records = new Map<string, ReferenceRecord>();
    for (const item of secondary) records.set(item.key, { key: item.key, entry: item.entry, rawEntry: item.rawEntry, inPrimary: false, inSecondary: true });
    for (const item of primary) records.set(item.key, { key: item.key, entry: item.entry, rawEntry: item.rawEntry, inPrimary: true, inSecondary: secondaryByKey.has(item.key) });
    const only = secondary.filter(item => !primaryKeys.has(item.key));
    const now = this.options.now?.() ?? Date.now();
    const canonical = (item: SourceEntry) => records.get(item.key)!;
    const ordinaryRecords = [...primary.map(canonical), ...only.filter(item => isRecent(item.rawEntry, now, this.recentDaysValue)).map(canonical)];
    const allRecords = [...primary.map(canonical), ...only.map(canonical)];
    const secondaryRecords = secondary.map(canonical);
    const foldedKeys = new Map<string, string | null>(); const compactKeys = new Map<string, string | null>(); const dois = new Map<string, string | null>();
    for (const record of allRecords) {
      addUniqueLookup(foldedKeys, record.key.toLowerCase(), record.key);
      addUniqueLookup(compactKeys, compactSearchText(record.key), record.key);
      const doi = normalizeDoi(record.rawEntry.DOI || record.rawEntry.doi); if (doi) addUniqueLookup(dois, doi, record.key);
    }
    return {
      primary: BibliographyIndex.fromEntries(primary.map(item => item.entry)),
      ordinary: BibliographyIndex.fromEntries(ordinaryRecords.map(record => record.entry)),
      all: BibliographyIndex.fromEntries(allRecords.map(record => record.entry)),
      secondary: BibliographyIndex.fromEntries(secondaryRecords.map(record => record.entry)),
      primaryKeys, records, foldedKeys, compactKeys, dois, orderedKeys: allRecords.map(record => record.key),
    };
  }
}

function addUniqueLookup(map: Map<string, string | null>, lookup: string, key: string): void {
  if (!lookup) return;
  const previous = map.get(lookup);
  if (previous === undefined) map.set(lookup, key);
  else if (previous !== key) map.set(lookup, null);
}
