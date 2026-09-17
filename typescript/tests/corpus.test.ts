import * as fs from 'fs'; import * as path from 'path'; import { BibliographyIndex } from '../src/bibliography';
const FIXTURE_PATH = path.resolve(process.cwd(), '../tests/fixtures/search_corpus.json');
describe('Shared Search Corpus', () => { test('preserves historical ranking contract', () => {
  const data = JSON.parse(fs.readFileSync(FIXTURE_PATH, 'utf8')); const bib = BibliographyIndex.fromEntries(data.dataset);
  for (const c of data.test_cases) { const ids = bib.search(c.query, 5).map((r: any) => r.id); for (const expected of c.must_include) expect(ids).toContain(expected); if (c.expected_first) expect(ids[0]).toBe(c.expected_first); }
}); });
