import os
import subprocess
from dataclasses import dataclass
from typing import Optional


class ToolNotFoundError(Exception):
    """Raised when an underlying CLI tool (e.g., cite2md) is not found in PATH."""


class ToolExecutionError(Exception):
    """Raised when an underlying CLI tool returns a non-zero exit status."""
    def __init__(self, cmd: list[str], exit_code: int, stderr: str | None = None):
        self.cmd = cmd
        self.exit_code = exit_code
        self.stderr = stderr
        message = f"Command failed: {' '.join(cmd)} (exit={exit_code})"
        if stderr:
            message += f"\n{stderr}"
        super().__init__(message)


@dataclass
class ActionResult:
    ok: bool
    error: Optional[str] = None


class AgentTools:
    """Synchronous wrapper around agent-tools CLI scripts."""
    def __init__(self, papers_dir: Optional[str] = None):
        self._env = os.environ.copy()
        if papers_dir:
            self._env["PAPERS_DIR"] = papers_dir

    def _run(self, cmd: list[str]) -> Optional[str]:
        try:
            # Do not use check=True so we can distinguish exit codes
            res = subprocess.run(cmd, capture_output=True, text=True, env=self._env, check=False)
        except FileNotFoundError as e:
            raise ToolNotFoundError(str(e))

        if res.returncode != 0:
            # Non-zero exit indicates an execution failure from the tool
            raise ToolExecutionError(cmd, res.returncode, res.stderr)

        stdout = (res.stdout or "").strip()
        return stdout if stdout else None

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

    def get_bib_entry(self, key: str) -> Optional[str]:
        """Returns the raw BibTeX entry for the given key."""
        val = self._run(["cite2bib", key])
        return val if val else None

    def open_vscode(self, key: str) -> ActionResult:
        """Opens the Markdown source in VS Code."""
        try:
            subprocess.Popen(["cite2md", "--vs", key], env=self._env)
            return ActionResult(ok=True)
        except FileNotFoundError as e:
            return ActionResult(ok=False, error=str(e))
        except Exception as e:
            return ActionResult(ok=False, error=str(e))

    def open_vscode_insiders(self, key: str) -> ActionResult:
        """Opens the Markdown source in VS Code Insiders."""
        try:
            subprocess.Popen(["cite2md", "--vsi", key], env=self._env)
            return ActionResult(ok=True)
        except FileNotFoundError as e:
            return ActionResult(ok=False, error=str(e))
        except Exception as e:
            return ActionResult(ok=False, error=str(e))

    def reveal_md(self, key: str) -> ActionResult:
        """Reveals the Markdown source in Finder/Explorer."""
        try:
            subprocess.Popen(["cite2md", "--reveal", key], env=self._env)
            return ActionResult(ok=True)
        except FileNotFoundError as e:
            return ActionResult(ok=False, error=str(e))
        except Exception as e:
            return ActionResult(ok=False, error=str(e))

    def open_pdf(self, key: str) -> ActionResult:
        """Opens the PDF in the default system viewer."""
        try:
            subprocess.Popen(["cite2pdf", "--open", key], env=self._env)
            return ActionResult(ok=True)
        except FileNotFoundError as e:
            return ActionResult(ok=False, error=str(e))
        except Exception as e:
            return ActionResult(ok=False, error=str(e))

    def reveal_pdf(self, key: str) -> ActionResult:
        """Reveals the PDF in Finder/Explorer."""
        try:
            subprocess.Popen(["cite2pdf", "--reveal", key], env=self._env)
            return ActionResult(ok=True)
        except FileNotFoundError as e:
            return ActionResult(ok=False, error=str(e))
        except Exception as e:
            return ActionResult(ok=False, error=str(e))
