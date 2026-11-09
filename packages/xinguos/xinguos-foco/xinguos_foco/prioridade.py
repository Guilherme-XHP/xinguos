"""Pesos de CPU e disco por app: scope do systemd --user ← pid; systemctl set-property."""
from __future__ import annotations

import logging
from pathlib import Path
from typing import Callable

log = logging.getLogger(__name__)


def scope_do_pid(pid: int, proc: Path = Path("/proc")) -> str | None:
    """Scope do app (…/app.slice/app-*.scope) a que o pid pertence, ou None."""
    if pid <= 0:
        return None
    try:
        texto = (proc / str(pid) / "cgroup").read_text()
    except (OSError, ValueError):
        return None
    for linha in texto.splitlines():
        if not linha.startswith("0::"):
            continue
        partes = linha[3:].strip().split("/")
        if len(partes) >= 2 and partes[-1].endswith(".scope") and partes[-2] == "app.slice":
            return partes[-1]
    return None


class Aplicador:
    def __init__(self, executar: Callable[[list[str]], int]):
        self.executar = executar
        self.aplicado: dict[str, int] = {}

    def aplicar(self, unit: str, peso: int) -> None:
        if self.aplicado.get(unit) == peso:
            return
        cmd = ["systemctl", "--user", "set-property", "--runtime", unit, f"CPUWeight={peso}", f"IOWeight={peso}"]
        try:
            rc = self.executar(cmd)
        except Exception as e:  # noqa: BLE001 — nunca derruba o daemon
            log.warning("falhou %s: %s", " ".join(cmd), e)
            return
        if rc != 0:
            log.warning("%s saiu com %s", " ".join(cmd), rc)
            return
        self.aplicado[unit] = peso

    def esquecer(self, unit: str) -> None:
        self.aplicado.pop(unit, None)
