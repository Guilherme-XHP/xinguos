"""foco.toml: prioridades, limites diários e autotile por app (spec 7.2 e 7.2.1)."""
from __future__ import annotations

import os
import tomllib
from dataclasses import dataclass, field
from pathlib import Path

PESO_SEMPRE = 1000
PESO_FOCO = 500
PESO_NORMAL = 100
PESO_SEGUNDO_PLANO = 25


@dataclass
class Config:
    sempre: set[str] = field(default_factory=set)
    segundo_plano: set[str] = field(default_factory=set)
    limites_min: dict[str, int] = field(default_factory=dict)
    sem_autotile: set[str] = field(default_factory=set)


def _ler(caminho: Path, avisos: list[str]) -> dict:
    try:
        with open(caminho, "rb") as f:
            return tomllib.load(f)
    except FileNotFoundError:
        return {}
    except (tomllib.TOMLDecodeError, OSError, UnicodeDecodeError) as e:
        avisos.append(f"foco.toml inválido: {caminho}: {e}")
        return {}


def _lista(valor, onde: str, avisos: list[str]) -> set[str]:
    if valor is None:
        return set()
    if not isinstance(valor, list) or not all(isinstance(x, str) for x in valor):
        avisos.append(f"foco.toml: {onde} precisa ser uma lista de textos; ignorado")
        return set()
    return set(valor)


def carregar(sistema: Path, usuario: Path) -> tuple[Config, list[str]]:
    avisos: list[str] = []
    dados = _ler(sistema, avisos)
    # cada chave de topo do usuário substitui a do sistema
    dados.update(_ler(usuario, avisos))

    prio = dados.get("prioridades", {})
    if not isinstance(prio, dict):
        avisos.append("foco.toml: [prioridades] precisa ser uma tabela; ignorado")
        prio = {}
    lim = dados.get("limites", {})
    if not isinstance(lim, dict):
        avisos.append("foco.toml: [limites] precisa ser uma tabela; ignorado")
        lim = {}
    auto = dados.get("autotile", {})
    if not isinstance(auto, dict):
        avisos.append("foco.toml: [autotile] precisa ser uma tabela; ignorado")
        auto = {}

    limites: dict[str, int] = {}
    for app, minutos in lim.items():
        if isinstance(minutos, int) and not isinstance(minutos, bool) and minutos > 0:
            limites[app] = minutos
        else:
            avisos.append(f"foco.toml: limite de {app!r} precisa ser um inteiro positivo (minutos); ignorado")

    cfg = Config(
        sempre=_lista(prio.get("sempre"), "prioridades.sempre", avisos),
        segundo_plano=_lista(prio.get("segundo_plano"), "prioridades.segundo_plano", avisos),
        limites_min=limites,
        sem_autotile=_lista(auto.get("nao"), "autotile.nao", avisos),
    )
    return cfg, avisos


def peso(app: str, cfg: Config, em_foco: bool) -> int:
    if app in cfg.sempre:
        return PESO_SEMPRE
    if app in cfg.segundo_plano:
        return PESO_SEGUNDO_PLANO
    if em_foco and app.startswith("steam_app_"):
        return PESO_SEMPRE  # jogo do Steam em foco (spec 7.2)
    return PESO_FOCO if em_foco else PESO_NORMAL


def _texto(s: str) -> str:
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


def _lista_toml(itens: set[str]) -> str:
    return "[" + ", ".join(_texto(x) for x in sorted(itens)) + "]"


def para_toml(cfg: Config) -> str:
    linhas = [
        "# XInguOS Foco — gerado pelo painel Foco; pode editar à mão",
        "[prioridades]",
        f"sempre = {_lista_toml(cfg.sempre)}",
        f"segundo_plano = {_lista_toml(cfg.segundo_plano)}",
        "",
        "[limites]",
        "# minutos por dia",
    ]
    linhas += [f"{_texto(app)} = {m}" for app, m in sorted(cfg.limites_min.items())]
    linhas += ["", "[autotile]", f"nao = {_lista_toml(cfg.sem_autotile)}", ""]
    return "\n".join(linhas)


def salvar(cfg: Config, usuario: Path) -> None:
    usuario.parent.mkdir(parents=True, exist_ok=True)
    tmp = usuario.with_name(usuario.name + ".tmp")
    with open(tmp, "w", encoding="utf-8", newline="\n") as f:
        f.write(para_toml(cfg))
        f.flush()
        os.fsync(f.fileno())
    os.replace(tmp, usuario)


def caminhos_padrao() -> tuple[Path, Path]:
    sistema = Path("/etc/xdg/xinguos/foco.toml")
    usu = os.environ.get("XINGUOS_FOCO_CONFIG")
    if usu:
        return sistema, Path(usu)
    base = Path(os.environ.get("XDG_CONFIG_HOME") or Path.home() / ".config")
    return sistema, base / "xinguos" / "foco.toml"
