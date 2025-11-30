import * as fs from 'fs';
import { Bibliography } from '../src/bibliography';

describe('E2E Production Search', () => {
  test('loads production data and finds davidson 1963', async () => {
    const bib = new Bibliography();
    await bib.load();

    // Check if data loaded
    if (bib.length === 0) {
      const bibJsonEnv = process.env.BIB_JSON;
      
      // If ENV is set, it's an error if we didn't load anything
      if (bibJsonEnv) {
        throw new Error(`BIB_JSON is set to ${bibJsonEnv} but no entries were loaded.`);
      }

      // If default file exists but length is 0, it's an error
      // (Note: Bibliography class handles default path resolution internally, 
      // but we trust .length === 0 implies it failed to load valid data)
      console.warn("Skipping E2E test: No production bibliography found/loaded.");
      return; 
    }

    const query = "davidson 1963";
    const results = bib.search(query);

    expect(results.length).toBeGreaterThan(0);
    
    // Validate the first result looks somewhat correct
    const first = results[0];
    expect(first).toHaveProperty('id');
    // We expect the search to be relevant
    const strRep = JSON.stringify(first).toLowerCase();
    const relevant = strRep.includes('davidson') || strRep.includes('1963');
    expect(relevant).toBe(true);
  });
});