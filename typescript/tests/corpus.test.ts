import * as fs from 'fs';
import * as path from 'path';
import * as os from 'os';
import { Bibliography } from '../src/bibliography';

// Use process.cwd() to anchor to the 'typescript/' folder, then go up one level
const FIXTURE_PATH = path.resolve(process.cwd(), '../tests/fixtures/search_corpus.json');

describe('Shared Search Corpus', () => {
  let bib: Bibliography;
  let corpusData: any;
  let tmpFile: string;

  beforeAll(async () => {
    // Debug check to ensure path is correct
    if (!fs.existsSync(FIXTURE_PATH)) {
      console.error(`\n❌ Could not find fixture at: ${FIXTURE_PATH}`);
      console.error(`Current Directory: ${process.cwd()}\n`);
      throw new Error("Fixture file missing");
    }

    const raw = fs.readFileSync(FIXTURE_PATH, 'utf-8');
    corpusData = JSON.parse(raw);

    tmpFile = path.join(os.tmpdir(), `test_bib_${Date.now()}.json`);
    fs.writeFileSync(tmpFile, JSON.stringify(corpusData.dataset));

    bib = new Bibliography(tmpFile);
    await bib.load();
  });

  afterAll(() => {
    if (fs.existsSync(tmpFile)) fs.unlinkSync(tmpFile);
  });

  test('runs all cases from corpus.json', () => {
    corpusData.test_cases.forEach((testCase: any) => {
      const results = bib.search(testCase.query, 5);
      const inMemory = Bibliography.fromEntries(corpusData.dataset);
      expect(inMemory.search(testCase.query, 5)).toEqual(results);
      const resultIds = results.map(r => r.id);

      testCase.must_include.forEach((expectedId: string) => {
        if (!resultIds.includes(expectedId)) {
          throw new Error(
            `Failed case '${testCase.description}': Query '${testCase.query}' ` +
            `expected '${expectedId}' but got [${resultIds.join(', ')}]`
          );
        }
      });

      if (testCase.expected_first && resultIds[0] !== testCase.expected_first) {
        throw new Error(
          `Failed case '${testCase.description}': Query '${testCase.query}' ` +
          `expected '${testCase.expected_first}' first but got [${resultIds.join(', ')}]`
        );
      }
    });
  });
});
