import fuzzysort from 'fuzzysort';

export interface CslEntry {
  id?: string | number;
  type?: string;
  title?: string;
  author?: { family?: string; given?: string }[];
  issued?: { 'date-parts'?: (number | string)[][] };
  'citation-key'?: string | number;
  [key: string]: any;
}

export interface SearchHit {
  entry: CslEntry;
  score: number;
  matchBasis: string[];
}

interface SearchRecord {
  index: number;
  obj: CslEntry;
  key: string;
  keyNorm: string;
  keyCompact: string;
  keyTokens: string[];
  authors: string;
  authorsNorm: string;
  authorsTokens: string[];
  title: string;
  titleNorm: string;
  titleTokens: string[];
  year: string;
  yearNorm: string;
  yearTokens: string[];
  full: string;
  fullNorm: string;
  fullTokens: string[];
}

interface QueryInfo {
  raw: string;
  norm: string;
  compact: string;
  tokens: string[];
}

/**
 * Pure in-memory bibliography ranker.
 *
 * Filesystem/source-role policy deliberately lives in ReferenceCatalog. This
 * class only indexes an already chosen set of immutable entries and preserves
 * the ranking semantics historically used by agent-tools/bibq-w.
 */
export class BibliographyIndex {
  public readonly entries: CslEntry[];
  private readonly searchIndex: SearchRecord[];

  private constructor(entries: readonly CslEntry[]) {
    this.entries = entries.slice();
    this.searchIndex = this.entries.map((entry, index) => this.buildSearchRecord(entry, index));
  }

  static fromEntries(entries: readonly CslEntry[]): BibliographyIndex {
    return new BibliographyIndex(entries);
  }

  get length(): number {
    return this.entries.length;
  }

  /**
   * Match evidence independent of search()'s legacy padded candidates.
   * Accepts normalized key containment or coverage of every query token using
   * the same prefix/typo matcher as ranking. Blank queries match nonempty indexes.
   * This is a widening heuristic, not a filter or a guarantee of relevance.
   */
  hasPlausibleMatch(query: string): boolean {
    if (!query.trim()) return this.entries.length > 0;
    const info = this.getQueryInfo(query);
    return this.searchIndex.some(record => this.isKeyCandidate(info, record) ||
      (info.tokens.length > 0 && info.tokens.every(token => tokenMatches(token, record.fullTokens))));
  }

  search(query: string, limit: number = 20): CslEntry[] {
    return this.searchHits(query, limit).map(hit => hit.entry);
  }

  /**
   * Ranked results with raw score and non-exclusive field evidence.
   * Scores are implementation details and are not promised to be comparable
   * across language bindings. Ordering is exactly the same as search().
   */
  searchHits(query: string, limit: number = 20): SearchHit[] {
    if (this.entries.length === 0 || limit <= 0) return [];
    if (!query) {
      return this.entries.slice(0, limit).map(entry => ({ entry, score: 0, matchBasis: [] }));
    }

    const queryInfo = this.getQueryInfo(query);
    const candidateIndexes = this.candidateIndexes(queryInfo, limit);
    return Array.from(candidateIndexes)
      .map(index => {
        const record = this.searchIndex[index];
        return {
          record,
          index,
          score: this.scoreRecord(queryInfo, record),
          matchBasis: this.matchBasis(queryInfo, record),
        };
      })
      .sort((a, b) => b.score - a.score || a.index - b.index)
      .slice(0, limit)
      .map(result => ({ entry: result.record.obj, score: result.score, matchBasis: result.matchBasis }));
  }

  private buildSearchRecord(e: CslEntry, index: number): SearchRecord {
    const year = this.getYear(e);
    const authors = this.getAuthors(e);
    const title = String(e.title || '');
    const key = String(e.id || e['citation-key'] || '');
    const full = `${year} ${authors} ${title} ${key}`;
    return {
      index, obj: e, key,
      keyNorm: normalize(key), keyCompact: compact(key), keyTokens: tokens(key),
      authors, authorsNorm: normalize(authors), authorsTokens: tokens(authors),
      title, titleNorm: normalize(title), titleTokens: tokens(title),
      year, yearNorm: normalize(year), yearTokens: tokens(year),
      full, fullNorm: normalize(full), fullTokens: tokens(full),
    };
  }

  private getAuthors(e: CslEntry): string {
    if (!Array.isArray(e.author)) return '';
    return e.author.map(author => author?.family || '').join(' ');
  }

  private getYear(e: CslEntry): string {
    try {
      const parts = e.issued?.['date-parts'];
      if (parts && Array.isArray(parts) && parts.length > 0) {
        const first = parts[0];
        if (Array.isArray(first) && first.length > 0) return String(first[0]);
      }
    } catch {
      // Ignore malformed date data; the historical ranker did the same.
    }
    return '';
  }

  private getQueryInfo(query: string): QueryInfo {
    return { raw: String(query || ''), norm: normalize(query), compact: compact(query), tokens: tokens(query) };
  }

  private candidateIndexes(query: QueryInfo, limit: number): Set<number> {
    const candidateLimit = Math.min(this.entries.length, Math.max(limit * 10, 200));
    const candidates = new Set<number>();
    const fuzzyResults = fuzzysort.go(query.raw, this.searchIndex, { key: 'full', limit: candidateLimit, threshold: -Infinity });
    fuzzyResults.forEach(result => candidates.add(result.obj.index));
    this.searchIndex.forEach(record => {
      if (this.isKeyCandidate(query, record) || this.hasFullTokenCoverage(query, record)) candidates.add(record.index);
    });
    // Historical behavior: pad with initial entries. ReferenceCatalog uses
    // hasPlausibleMatch() separately when it needs relevance evidence.
    if (candidates.size < limit) {
      for (let index = 0; index < Math.min(this.entries.length, limit); index += 1) candidates.add(index);
    }
    return candidates;
  }

  private isKeyCandidate(query: QueryInfo, record: SearchRecord): boolean {
    return Boolean(query.compact && record.keyCompact && (
      query.compact === record.keyCompact ||
      record.keyCompact.startsWith(query.compact) ||
      record.keyCompact.includes(query.compact)
    ));
  }

  private hasFullTokenCoverage(query: QueryInfo, record: SearchRecord): boolean {
    return query.tokens.length > 0 && query.tokens.every(token => strictTokenMatches(token, record.fullTokens));
  }

  private scoreRecord(query: QueryInfo, record: SearchRecord): number {
    let score = Math.max(
      similarity(query.norm, record.fullNorm) * 0.55,
      containsSimilarity(query.norm, record.fullNorm) * 0.45,
      tokenSetSimilarity(query.norm, record.fullNorm) * 0.55,
      similarity(query.norm, record.keyNorm) * 0.90,
      similarity(query.norm, record.authorsNorm) * 0.75,
      similarity(query.norm, record.titleNorm) * 0.70,
    );
    if (query.compact && record.keyCompact) {
      score = Math.max(score,
        partialSimilarity(query.compact, record.keyCompact) * 0.95,
        similarity(query.compact, record.keyCompact) * 0.90,
      );
      if (query.compact === record.keyCompact) score += 50;
      else if (query.compact.length >= 3 && record.keyCompact.startsWith(query.compact)) score += 25;
    }
    if (query.tokens.length === 0) return score;
    const covered = query.tokens.filter(token => tokenMatches(token, record.fullTokens)).length;
    score += 8 * covered / query.tokens.length;
    const hasAuthorToken = query.tokens.some(token => tokenMatches(token, record.authorsTokens));
    const hasTitleOrKeyToken = query.tokens.some(token => tokenMatches(token, record.titleTokens) || tokenMatches(token, record.keyTokens));
    if (hasAuthorToken && hasTitleOrKeyToken) score += 12;
    if (query.tokens.some(token => tokenMatches(token, record.yearTokens))) score += 8;
    return score;
  }

  private matchBasis(query: QueryInfo, record: SearchRecord): string[] {
    const basis = new Set<string>();
    if (query.compact && record.keyCompact && (
      query.compact === record.keyCompact ||
      (query.compact.length >= 3 && record.keyCompact.startsWith(query.compact))
    )) basis.add('key');
    if (query.tokens.some(token => tokenMatches(token, record.authorsTokens))) basis.add('author');
    if (query.tokens.some(token => tokenMatches(token, record.titleTokens))) basis.add('title');
    if (query.tokens.some(token => tokenMatches(token, record.yearTokens))) basis.add('year');
    return Array.from(basis).sort();
  }
}

export function normalizeSearchText(value: unknown): string {
  return String(value || '')
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

export function compactSearchText(value: unknown): string {
  return normalizeSearchText(value).replace(/[^a-z0-9]+/g, '');
}

function normalize(value: unknown): string { return normalizeSearchText(value); }
function compact(value: unknown): string { return compactSearchText(value); }
function tokens(value: unknown): string[] { const normalized = normalize(value); return normalized ? normalized.split(' ') : []; }
function tokenMatches(token: string, candidates: string[]): boolean {
  return candidates.some(candidate => candidate === token || candidate.startsWith(token) || similarity(token, candidate) >= 82);
}
function strictTokenMatches(token: string, candidates: string[]): boolean {
  return candidates.some(candidate => candidate === token || candidate.startsWith(token));
}
function tokenSetSimilarity(a: string, b: string): number {
  const aTokens = tokens(a); const bTokens = tokens(b);
  if (aTokens.length === 0 || bTokens.length === 0) return 0;
  const total = aTokens.reduce((sum, token) => {
    const best = bTokens.reduce((max, candidate) => Math.max(max, tokenMatches(token, [candidate]) ? 100 : similarity(token, candidate)), 0);
    return sum + best;
  }, 0);
  return total / aTokens.length;
}
function partialSimilarity(needle: string, haystack: string): number {
  if (!needle || !haystack) return 0;
  if (haystack.includes(needle)) return 100;
  if (needle.length > haystack.length) return similarity(needle, haystack);
  let best = 0;
  for (let i = 0; i <= haystack.length - needle.length; i += 1) best = Math.max(best, similarity(needle, haystack.slice(i, i + needle.length)));
  return best;
}
function containsSimilarity(needle: string, haystack: string): number { return !needle || !haystack ? 0 : haystack.includes(needle) ? 100 : 0; }
function similarity(a: string, b: string): number {
  if (!a && !b) return 100;
  if (!a || !b) return 0;
  if (a === b) return 100;
  const distance = levenshtein(a, b);
  return Math.max(0, 100 * (1 - distance / Math.max(a.length, b.length)));
}
function levenshtein(a: string, b: string): number {
  const previous = Array.from({ length: b.length + 1 }, (_, index) => index);
  const current = Array.from({ length: b.length + 1 }, () => 0);
  for (let i = 1; i <= a.length; i += 1) {
    current[0] = i;
    for (let j = 1; j <= b.length; j += 1) {
      const cost = a[i - 1] === b[j - 1] ? 0 : 1;
      current[j] = Math.min(current[j - 1] + 1, previous[j] + 1, previous[j - 1] + cost);
    }
    for (let j = 0; j <= b.length; j += 1) previous[j] = current[j];
  }
  return previous[b.length];
}
