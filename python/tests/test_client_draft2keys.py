import types
from agent_tools.client import AgentTools

class DummyCompleted:
    def __init__(self, returncode=0, stdout='', stderr=''):
        self.returncode = returncode
        self.stdout = stdout
        self.stderr = stderr


def test_get_keys_from_draft_parses_lines(monkeypatch, tmp_path):
    calls = []

    def fake_run(cmd, capture_output, text, env, check):
        # capture the cmd for assertion
        calls.append(cmd)
        return DummyCompleted(returncode=0, stdout='alpha\n beta\r\n  \n gamma ', stderr='')

    # Monkeypatch subprocess.run used by AgentTools._run
    import subprocess
    monkeypatch.setattr(subprocess, 'run', fake_run)

    tools = AgentTools()
    keys = tools.get_keys_from_draft(str(tmp_path / 'draft.md'))

    # Ensure correct command is invoked
    assert calls and calls[0][0] == 'draft2keys'
    # Ensure parsing behavior: trims and filters blanks
    assert keys == ['alpha', 'beta', 'gamma']


def test_get_keys_from_draft_empty_output(monkeypatch, tmp_path):
    def fake_run(cmd, capture_output, text, env, check):
        return DummyCompleted(returncode=0, stdout='', stderr='')

    import subprocess
    monkeypatch.setattr(subprocess, 'run', fake_run)

    tools = AgentTools()
    keys = tools.get_keys_from_draft(str(tmp_path / 'draft.md'))
    assert keys == []
