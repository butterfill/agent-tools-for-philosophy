import { Bibliography, CslEntry } from '../src/bibliography';

const entries: CslEntry[] = [
  { id: 'davidson:1963_actions', type: 'article-journal', title: 'Actions, Reasons, and Causes', author: [{ family: 'Davidson' }], issued: { 'date-parts': [[1963]] } },
  { id: 'aaroe:2017_behavioral', type: 'article-journal', title: 'Behavioral research', author: [{ family: 'Aarøe' }], issued: { 'date-parts': [[2017]] } },
];

describe('in-memory bibliography indexes', () => {
  test('are immediately searchable and copy array membership without reordering entries', () => {
    const input = entries.slice();
    const bib = Bibliography.fromEntries(input);
    input.splice(0);
    expect(bib.length).toBe(2);
    expect(bib.search('')).toEqual(entries);
    expect(bib.search('behavioral', 1)).toEqual([entries[1]]);
    expect(Bibliography.fromEntries([]).search('anything')).toEqual([]);
  });

  test('preserves sparse entries and nonstandard keys', () => {
    const sparse = [':_americans', ':2009_oxford', '+:2005_brains', '43138'].map(id => ({ id, type: 'book' }));
    const bib = Bibliography.fromEntries(sparse);
    for (const entry of sparse) {
      expect(bib.hasPlausibleMatch(entry.id)).toBe(true);
      expect(bib.search(entry.id, 1)[0]).toBe(entry);
    }
  });
});

describe('plausible match evidence', () => {
  const bib = Bibliography.fromEntries(entries);
  test.each(['davidson:1963_actions', 'davidson1963', 'actions', 'davidsom reasons', 'Davidson 1963', 'behav resear'])('recognizes %s using existing match semantics', query => {
    expect(bib.hasPlausibleMatch(query)).toBe(true);
  });
  test.each(['zzzzqqqq', 'davidson zzzzqqqq', '!!!'])('rejects %s even though legacy search pads results', query => {
    const before = bib.search(query);
    expect(before.length).toBeGreaterThan(0);
    expect(bib.hasPlausibleMatch(query)).toBe(false);
    expect(bib.search(query)).toEqual(before);
  });
  test('blank queries match only nonempty indexes', () => {
    for (const query of ['', '  \t']) {
      expect(bib.hasPlausibleMatch(query)).toBe(true);
      expect(Bibliography.fromEntries([]).hasPlausibleMatch(query)).toBe(false);
    }
  });
});
