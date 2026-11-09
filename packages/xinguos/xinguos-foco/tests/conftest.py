import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))


def pytest_configure(config):
    config.addinivalue_line("markers", "dbus: precisa de um barramento de sessão (dbus-run-session)")
    config.addinivalue_line("markers", "qt: precisa do PySide6")
