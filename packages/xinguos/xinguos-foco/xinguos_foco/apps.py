"""Nome e ícone de um app a partir do .desktop dele."""
from __future__ import annotations

import os
from pathlib import Path

ICONE_PADRAO = "application-x-executable"


def dirs_padrao() -> list[Path]:
    dados = os.environ.get("XDG_DATA_HOME") or str(Path.home() / ".local/share")
    sistema = os.environ.get("XDG_DATA_DIRS") or "/usr/local/share:/usr/share"
    dirs = [dados] + sistema.split(":") + ["/var/lib/flatpak/exports/share"]
    return [Path(d) / "applications" for d in dirs if d]


def _ler_entrada(caminho: Path) -> dict[str, str]:
    campos: dict[str, str] = {}
    grupo = None
    try:
        linhas = caminho.read_text(encoding="utf-8", errors="replace").splitlines()
    except OSError:
        return campos
    for linha in linhas:
        linha = linha.strip()
        if linha.startswith("["):
            grupo = linha
            continue
        if grupo == "[Desktop Entry]" and "=" in linha and not linha.startswith("#"):
            chave, valor = linha.split("=", 1)
            campos.setdefault(chave.strip(), valor.strip())
    return campos


def nome_e_icone(app: str, dirs: list[Path] | None = None) -> tuple[str, str]:
    for d in dirs_padrao() if dirs is None else dirs:
        arq = d / f"{app}.desktop"
        if arq.is_file():
            c = _ler_entrada(arq)
            nome = c.get("Name[pt_BR]") or c.get("Name[pt]") or c.get("Name") or app
            return nome, c.get("Icon") or ICONE_PADRAO
    return app, ICONE_PADRAO
