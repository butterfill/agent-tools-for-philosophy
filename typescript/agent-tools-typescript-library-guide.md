# TypeScript Developer Guide for `agent-tools`

This package provides TypeScript bindings for the `agent-tools` shell suite, allowing Node.js applications (such as AI agents) to search bibliographies, resolve citations to file paths, and read full-text content.

## Installation

```bash
# Via Git
pnpm install "git+ssh://git@github.com/butterfill/agent-tools.git#subdirectory=typescript"

# Or local development linking
pnpm link ./typescript
```

## Prerequisites

The TypeScript wrapper relies on the underlying shell scripts being installed and available in your system `$PATH`.

1. Run `./install.sh` in the root of this repository.
2. Ensure `PAPERS_DIR` and `BIB_JSON` environment variables are set, or pass them to the constructors explicitly.

## Core Components

The library exports two main classes: `AgentTools` (CLI wrapper) and `Bibliography` (Search).

### 1. `AgentTools` Client

The `AgentTools` class provides a programmatic interface to the shell scripts (`cite2md`, `cite2pdf`, etc.). It spawns child processes to execute commands.

**Import:**
```typescript
import { AgentTools } from '@butterfill/agent-tools';
```

**Usage:**
```typescript
// Optional: Pass papers directory. Defaults to process.env.PAPERS_DIR
const client = new AgentTools('/Users/me/papers');

// 1. Get full text content (wraps `cite2md --cat`)
const markdown = await client.getMdContent('vesper:2012_jumping');
if (markdown) {
  console.log('File content:', markdown);
}

// 2. Get absolute file paths
const mdPath = await client.getMdPath('vesper:2012_jumping');
const pdfPath = await client.getPdfPath('vesper:2012_jumping');

// 3. Get raw BibTeX entry
const bibTex = await client.getBibEntry('vesper:2012_jumping');

// 4. Fire-and-forget UI actions (opens local apps)
client.openVsCode('vesper:2012_jumping');
client.openPdf('vesper:2012_jumping');
client.revealMd('vesper:2012_jumping'); // Show in Finder/Explorer
```

### 2. `Bibliography` Engine

The `Bibliography` class loads a CSL-JSON file into memory and provides fuzzy search capabilities suitable for finding citations based on partial queries (author, year, title).

**Import:**
```typescript
import { Bibliography, CslEntry } from '@butterfill/agent-tools';
```

**Usage:**
```typescript
// Optional: Pass CSL-JSON path. Defaults to process.env.BIB_JSON
// Loads data synchronously upon instantiation.
const bib = new Bibliography('/Users/me/endnote/phd_biblio.json');

console.log(`Loaded ${bib.length} entries.`);

// Fuzzy search (Author, Year, Title, ID)
const limit = 5;
const results: CslEntry[] = bib.search('davidson reasons', limit);

results.forEach(entry => {
  console.log(entry.id);    // e.g., "davidson:1963_actions"
  console.log(entry.title); // e.g., "Actions, Reasons, and Causes"
  console.log(entry.type);  // e.g., "article-journal"
});
```

## Type Definitions

### `CslEntry`
Represents a parsed CSL-JSON bibliography item.

```typescript
interface CslEntry {
  id: string;
  type: string;
  title?: string;
  author?: { 
    family?: string; 
    given?: string 
  }[];
  issued?: { 
    'date-parts'?: (number | string)[][] 
  };
  [key: string]: any; // Allows for dynamic CSL fields
}
```

## Error Handling

*   **`AgentTools`**: Methods return `null` if the key cannot be resolved, the file is missing, or the CLI tool returns a non-zero exit code. They do *not* typically throw errors unless the child process fails to spawn (e.g., tool not in PATH).
*   **`Bibliography`**: If the JSON file cannot be loaded, `bib.entries` defaults to an empty array and `bib.length` will be 0. Use `try/catch` around `new Bibliography()` if you strictly require the file to exist.

## Configuration

The wrappers respect the standard environment variables used by the shell tools:

| Variable | Description |
| :--- | :--- |
| `PAPERS_DIR` | Root directory for Markdown sources and PDFs. |
| `BIB_JSON` | Path to the CSL-JSON bibliography file (for `Bibliography` class). |
| `BIB_FILE` | Path to the BibTeX file (used indirectly by `cite2bib`). |