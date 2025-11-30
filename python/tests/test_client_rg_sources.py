from agent_tools.client import AgentTools

class DummyCompleted:
    def __init__(self, returncode=0, stdout='', stderr=''):
        self.returncode = returncode
        self.stdout = stdout
        self.stderr = stderr

def test_rg_sources_raw_and_lines(monkeypatch):
    def fake_run(cmd, capture_output, text, env, check):
        # Simulate rg-sources output
        return DummyCompleted(returncode=0, stdout='a\n b \n', stderr='')

    import subprocess
    monkeypatch.setattr(subprocess, 'run', fake_run)

    tools = AgentTools()

    raw = tools.rg_sources(['-n', 'pattern'])
    assert raw == 'a\n b'

    lines = tools.rg_sources_lines(['-l', 'pattern'])
    assert lines == ['a', ' b ']


def test_rg_sources_empty(monkeypatch):
    def fake_run(cmd, capture_output, text, env, check):
        return DummyCompleted(returncode=0, stdout='', stderr='')

    import subprocess
    monkeypatch.setattr(subprocess, 'run', fake_run)

    tools = AgentTools()
    assert tools.rg_sources(['-n', 'x']) is None
    assert tools.rg_sources_lines(['-n', 'x']) == []
