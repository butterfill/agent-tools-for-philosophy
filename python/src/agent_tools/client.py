import os
import subprocess
from typing import Optional

class AgentTools:
    """Synchronous wrapper around agent-tools CLI scripts."""
    def __init__(self, papers_dir: Optional[str] = None):
        self._env = os.environ.copy()
        if papers_dir:
            self._env["PAPERS_DIR"] = papers_dir

    def _run(self, cmd: list[str]) -> str:
        try:
            # Assumes tools are in PATH via install.sh
            res = subprocess.run(cmd, capture_output=True, text=True, env=self._env, check=True)
            return res.stdout.strip()
        except (subprocess.CalledProcessError, FileNotFoundError):
            return ""

    def get_md_path(self, key: str) -> Optional[str]:
        val = self._run(["cite2md", key])
        return val if val else None

    def get_pdf_path(self, key: str) -> Optional[str]:
        val = self._run(["cite2pdf", key])
        return val if val else None

    def get_md_content(self, key: str) -> Optional[str]:
        """Returns the full text content of the Markdown source."""
        val = self._run(["cite2md", "--cat", key])
        return val if val else None

    def open_vscode(self, key: str) -> None:
        """Opens the Markdown source in VS Code."""
        subprocess.Popen(["cite2md", "--vs", key], env=self._env)

    def open_vscode_insiders(self, key: str) -> None:
        """Opens the Markdown source in VS Code Insiders."""
        subprocess.Popen(["cite2md", "--vsi", key], env=self._env)

    def reveal_md(self, key: str) -> None:
        """Reveals the Markdown source in Finder/Explorer."""
        subprocess.Popen(["cite2md", "--reveal", key], env=self._env)

    def open_pdf(self, key: str) -> None:
        """Opens the PDF in the default system viewer."""
        subprocess.Popen(["cite2pdf", "--open", key], env=self._env)

    def reveal_pdf(self, key: str) -> None:
        """Reveals the PDF in Finder/Explorer."""
        subprocess.Popen(["cite2pdf", "--reveal", key], env=self._env)