# Python Developer Guide: `agent-tools`

This package provides Python bindings for the `agent-tools` shell suite. It offers two primary components:
1.  **`AgentToolsClient`**: A wrapper around the shell CLI tools (like `cite2md`, `cite2pdf`) to interact with the file system.
2.  **`Bibliography`**: A pure Python class for high-performance fuzzy searching of your CSL-JSON bibliography.

## 1. Installation

You can install the package directly from the repository using `pip` or `uv`.

```bash
# Using pip
pip install "git+ssh://git@github.com/butterfill/agent-tools.git#subdirectory=python"

# Using uv
uv add "agent-tools @ git+ssh://git@github.com/butterfill/agent-tools.git#subdirectory=python"
```

### Prerequisites
The Python package relies on the underlying shell scripts for file operations. Ensure you have run the main installation script and the tools are in your `PATH`.

```bash
./install.sh
```

## 2. Configuration

The library uses the same environment variables as the CLI tools.

*   `PAPERS_DIR`: Path to your Markdown notes (Default: `~/papers`).
*   `BIB_JSON`: Path to your CSL-JSON bibliography (Default: `~/endnote/phd_biblio.json`).

## 3. Usage: `AgentToolsClient`

Use `AgentToolsClient` to resolve citations to file paths or content. This is a synchronous wrapper around `subprocess` calls to `cite2md`, `cite2pdf`, etc.

```python
from agent_tools import AgentToolsClient

# Initialize (optional: override PAPERS_DIR)
client = AgentToolsClient(papers_dir="/users/me/papers")

# 1. Resolve a key to a Markdown path
md_path = client.get_md_path("vesper:2012_jumping")
if md_path:
    print(f"Found markdown at: {md_path}")

# 2. Get full content (equivalent to cite2md --cat)
content = client.get_md_content("vesper:2012_jumping")

# 3. Resolve PDF path
pdf_path = client.get_pdf_path("vesper:2012_jumping")

# 4. Human Interactions (fire-and-forget UI actions)
# These open the file in the respective application
client.open_vscode("vesper:2012_jumping")
client.open_pdf("vesper:2012_jumping")
client.reveal_md("vesper:2012_jumping") # Show in Finder/Explorer
```

**Return Types:**
All getter methods return `Optional[str]`. You must handle `None` (key not found).

## 4. Usage: `Bibliography`

Use the `Bibliography` class to search your reference library. This runs entirely in Python using `rapidfuzz` and does not spawn shell processes.

```python
from agent_tools import Bibliography

# Initialize (loads data from env var BIB_JSON or default path)
bib = Bibliography()

# Search
# Query matches against Author, Year, Title, and ID
results = bib.search("davidson 1963", limit=5)

for item in results:
    # item is a CSL-JSON dictionary
    print(f"Key: {item.get('id')}")
    print(f"Title: {item.get('title')}")
    print(f"Type: {item.get('type')}")
```

**Data Structure:**
The `results` are standard CSL-JSON dictionaries (parsed from your JSON file).

## 5. API Reference

### `class AgentToolsClient`

*   `__init__(papers_dir: Optional[str] = None)`
*   `get_md_path(key: str) -> Optional[str]`
    *   Returns absolute path to `.md` file.
*   `get_pdf_path(key: str) -> Optional[str]`
    *   Returns absolute path to `.pdf` file.
*   `get_md_content(key: str) -> Optional[str]`
    *   Returns the full text content of the Markdown file.
*   `get_bib_entry(key: str) -> Optional[str]`
    *   Returns the raw BibTeX entry string.
*   `open_vscode(key: str) -> None`: Opens in `code`.
*   `open_vscode_insiders(key: str) -> None`: Opens in `code-insiders`.
*   `open_pdf(key: str) -> None`: Opens in system default PDF viewer.
*   `reveal_md(key: str) -> None`: Reveals file in Finder/Explorer.

### `class Bibliography`

*   `__init__(json_path: str = None)`
    *   Loads the bibliography into memory. Uses `BIB_JSON` env var if `json_path` is not provided.
*   `search(query: str, limit: int = 20) -> List[Dict]`
    *   Performs a fuzzy search. Returns a list of CSL-JSON objects.
    *   If `query` is empty, returns the first `limit` items.
*   `load() -> None`
    *   Reloads the JSON file from disk. Called automatically on init.
*   `__len__() -> int`
    *   Returns total number of entries.