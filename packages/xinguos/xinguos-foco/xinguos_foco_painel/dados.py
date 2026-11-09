"""Dados do painel Foco: resumos para as abas e gravação das mudanças (Python puro, testável)."""
from __future__ import annotations

from datetime import date
from pathlib import Path
from typing import Callable

from xinguos_foco.apps import nome_e_icone  # noqa: F401 — reexportado para o painel
from xinguos_foco.banco import Banco
from xinguos_foco.config import Config, salvar

# o mesmo ignoreClass que o xinguos-primeiro-login grava (Plano 4); um teste confere que não divergem
IGNORE_PADRAO = [
    "krunner", "yakuake", "spectacle", "kded5", "xwaylandvideobridge", "plasmashell", "ksplashqml",
    "org.kde.plasmashell", "org.kde.polkit-kde-authentication-agent-1", "org.kde.kruler", "kruler",
    "kwin_wayland", "ksmserver-logout-greeter", "kdenlive", "org.kde.kdenlive", "blender", "natron",
    "gimp", "obs", "com.obsproject.Studio", "steam", "gamescope", "[steam_app_]",
]

DIAS = ["seg", "ter", "qua", "qui", "sex", "sáb", "dom"]


def texto_tempo(segundos: int) -> str:
    minutos = int(segundos) // 60
    if minutos < 1:
        return "<1 min"
    if minutos < 60:
        return f"{minutos} min"
    return f"{minutos // 60} h {minutos % 60:02d} min"


def resumo_hoje(banco: Banco, hoje: date, dirs: list[Path] | None = None) -> list[dict]:
    resultado = []
    for app, segundos in banco.totais_do_dia(hoje):
        nome, icone = nome_e_icone(app, dirs)
        resultado.append({"app": app, "nome": nome, "icone": icone, "segundos": segundos,
                          "texto": texto_tempo(segundos)})
    return resultado


def resumo_semana(banco: Banco, hoje: date) -> list[dict]:
    return [{"dia": f"{DIAS[dia.weekday()]} {dia:%d/%m}", "segundos": s, "texto": texto_tempo(s)}
            for dia, s in banco.totais_por_dia(hoje, 7).items()]


def _prioridade(app: str, cfg: Config) -> str:
    if app in cfg.sempre:
        return "sempre"
    if app in cfg.segundo_plano:
        return "segundo_plano"
    return "normal"


def apps_conhecidos(banco: Banco, cfg: Config, dirs: list[Path] | None = None) -> list[dict]:
    todos = set(banco.apps()) | cfg.sempre | cfg.segundo_plano | set(cfg.limites_min) | cfg.sem_autotile
    resultado = []
    for app in todos:
        nome, icone = nome_e_icone(app, dirs)
        resultado.append({"app": app, "nome": nome, "icone": icone, "prioridade": _prioridade(app, cfg),
                          "limite_min": cfg.limites_min.get(app), "autotile": app not in cfg.sem_autotile})
    return sorted(resultado, key=lambda a: (a["nome"].lower(), a["app"]))


def classes_da_janela(app: str) -> list[str]:
    """Id do app e o nome curto: no Wayland a classe da janela costuma ser o id (org.kde.kdenlive),
    no XWayland, o nome curto (kdenlive)."""
    curto = app.rsplit(".", 1)[-1].lower()
    return [app] if curto == app else [app, curto]


def ignore_class(cfg: Config) -> str:
    lista = list(IGNORE_PADRAO)
    for app in sorted(cfg.sem_autotile):
        for c in classes_da_janela(app):
            if c and c not in lista and "," not in c:
                lista.append(c)
    return ",".join(lista)


def aplicar_mudancas(cfg: Config, mudancas: list[dict], usuario: Path,
                     escrever_kwin: Callable[[list[str]], int]) -> None:
    for m in mudancas:
        app = str(m.get("app") or "").strip()
        if not app:
            continue
        cfg.sempre.discard(app)
        cfg.segundo_plano.discard(app)
        prioridade = m.get("prioridade", "normal")
        if prioridade == "sempre":
            cfg.sempre.add(app)
        elif prioridade == "segundo_plano":
            cfg.segundo_plano.add(app)
        limite = m.get("limite_min")
        if isinstance(limite, (int, float)) and int(limite) > 0:
            cfg.limites_min[app] = int(limite)
        else:
            cfg.limites_min.pop(app, None)
        if m.get("autotile", True):
            cfg.sem_autotile.discard(app)
        else:
            cfg.sem_autotile.add(app)
    salvar(cfg, usuario)
    escrever_kwin(["kwriteconfig6", "--file", "kwinrc", "--group", "Script-krohnkite", "--key", "ignoreClass",
                   ignore_class(cfg)])
