import { BibliographyIndex, type CslEntry } from '../src/bibliography';

const entries: CslEntry[] = [
  { id: 'davidson:1963_actions', type: 'article-journal', title: 'Actions, Reasons, and Causes', author: [{ family: 'Davidson' }], issued: { 'date-parts': [[1963]] } },
  { id: 'aaroe:2017_behavioral', type: 'article-journal', title: 'Behavioral research', author: [{ family: 'Aarøe' }], issued: { 'date-parts': [[2017]] } },
];

describe('BibliographyIndex', () => {
  test('preserves historical in-memory search ordering', () => {
    const input = entries.slice(); const bib = BibliographyIndex.fromEntries(input); input.splice(0);
    expect(bib.length).toBe(2); expect(bib.search('')).toEqual(entries); expect(bib.search('behavioral', 1)).toEqual([entries[1]]);
  });
  test('preserves sparse/nonstandard keys', () => {
    const sparse = [':_americans', ':2009_oxford', '+:2005_brains', '43138'].map(id => ({ id, type: 'book' }));
    const bib = BibliographyIndex.fromEntries(sparse);
    for (const entry of sparse) { expect(bib.hasPlausibleMatch(String(entry.id))).toBe(true); expect(bib.search(String(entry.id), 1)[0]).toBe(entry); }
  });
  test('detailed hits preserve search order', () => {
    const bib = BibliographyIndex.fromEntries(entries); const hits = bib.searchHits('Davidson 1963', 2);
    expect(hits.map(hit => hit.entry)).toEqual(bib.search('Davidson 1963', 2)); expect(hits[0].score).toBeGreaterThan(0); expect(hits[0].matchBasis).toEqual(expect.arrayContaining(['author','year']));
  });
  test.each(['davidson:1963_actions','davidson1963','actions','davidsom reasons','Davidson 1963','behav resear'])('plausible match: %s', query => expect(BibliographyIndex.fromEntries(entries).hasPlausibleMatch(query)).toBe(true));
  test.each(['zzzzqqqq','davidson zzzzqqqq','!!!'])('padding is not plausibility: %s', query => {
    const bib = BibliographyIndex.fromEntries(entries); expect(bib.search(query).length).toBeGreaterThan(0); expect(bib.hasPlausibleMatch(query)).toBe(false);
  });
});
