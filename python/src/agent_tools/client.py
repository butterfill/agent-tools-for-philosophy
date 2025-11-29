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

    def open_vscode(self, key: str) -> None:
        subprocess.Popen(["cite2md", "--vs", key], env=self._env)