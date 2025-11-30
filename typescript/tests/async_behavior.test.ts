import * as fs from 'fs';
import * as path from 'path';
import * as os from 'os';
import { Bibliography } from '../src/bibliography';

describe('Bibliography Async Behavior', () => {
  let tmpFile: string;

  beforeAll(() => {
    tmpFile = path.join(os.tmpdir(), `async_test_${Date.now()}.json`);
    const data = {
      items: [{ id: 'test:1', title: 'Async Title', type: 'article' }]
    };
    fs.writeFileSync(tmpFile, JSON.stringify(data));
  });

  afterAll(() => {
    if (fs.existsSync(tmpFile)) fs.unlinkSync(tmpFile);
  });

  test('search returns empty array before load() is called', () => {
    // This confirms the "safe by default" behavior, even if potentially confusing
    const bib = new Bibliography(tmpFile);
    expect(bib.length).toBe(0);
    expect(bib.search('Async')).toEqual([]);
  });

  test('search works after await load()', async () => {
    const bib = new Bibliography(tmpFile);
    await bib.load();
    expect(bib.length).toBe(1);
    expect(bib.search('Async')[0].id).toBe('test:1');
  });

  test('load() handles non-existent file gracefully (empty lib)', async () => {
    const bib = new Bibliography('/non/existent/path.json');
    await bib.load();
    expect(bib.length).toBe(0);
    // Should not throw
  });

  test('load() throws on invalid JSON (if improvement applied)', async () => {
    const badFile = path.join(os.tmpdir(), `bad_json_${Date.now()}.json`);
    fs.writeFileSync(badFile, '{ "broken": ... '); // Invalid JSON
    
    const bib = new Bibliography(badFile);
    
    // If the improvement in Step 1 is applied, this assertion passes.
    // If the original code is kept, this will fail (it would resolve successfully with 0 entries).
    await expect(bib.load()).rejects.toThrow();
    
    if (fs.existsSync(badFile)) fs.unlinkSync(badFile);
  });
});