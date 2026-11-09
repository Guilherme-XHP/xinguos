"""Se o "Bem-vindo" já foi visto, e os avisos do xinguos-hwdetect."""
import os
from pathlib import Path

MARCA = "boasvindas-v1"


def dir_estado() -> Path:
    return Path(os.environ.get("XDG_STATE_HOME") or Path.home() / ".local/state") / "xinguos"


def ja_visto(estado_dir: Path) -> bool:
    return (Path(estado_dir) / MARCA).exists()


def marcar_visto(estado_dir: Path) -> None:
    d = Path(estado_dir)
    d.mkdir(parents=True, exist_ok=True)
    (d / MARCA).touch()


def aviso_hw(saida_detectar: str) -> str:
    for linha in saida_detectar.splitlines():
        if linha.startswith("aviso="):
            return linha[len("aviso="):].strip()
    return ""
