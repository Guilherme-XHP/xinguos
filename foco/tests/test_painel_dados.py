import os
import re
from datetime import date, datetime
from pathlib import Path

import pytest

from xinguos_foco.banco import Banco
from xinguos_foco.config import Config, carregar
from xinguos_foco_painel import dados

RAIZ = Path(__file__).resolve().parents[2]


def ts(texto):
    return datetime.fromisoformat(texto).timestamp()


def test_texto_de_tempo():
    assert dados.texto_tempo(0) == "<1 min"
    assert dados.texto_tempo(59) == "<1 min"
    assert dados.texto_tempo(12 * 60 + 30) == "12 min"
    assert dados.texto_tempo(3600 + 5 * 60) == "1 h 05 min"
    assert dados.texto_tempo(2 * 3600) == "2 h 00 min"


def test_semana_tem_7_dias_terminando_hoje(tmp_path):
    b = Banco(tmp_path / "f.db")
    b.registrar("steam", ts("2026-11-09 10:00:00"), ts("2026-11-09 11:00:00"))
    s = dados.resumo_semana(b, date(2026, 11, 9))
    assert [x["dia"] for x in s] == ["ter 03/11", "qua 04/11", "qui 05/11", "sex 06/11", "sáb 07/11", "dom 08/11", "seg 09/11"]
    assert s[-1]["segundos"] == 3600 and s[-1]["texto"] == "1 h 00 min"
    assert s[0]["segundos"] == 0


def test_resumo_hoje_com_nome_e_icone(tmp_path):
    apps = tmp_path / "apps"
    apps.mkdir()
    (apps / "steam.desktop").write_text("[Desktop Entry]\nName=Steam\nIcon=steam\n", encoding="utf-8")
    b = Banco(tmp_path / "f.db")
    b.registrar("steam", ts("2026-11-09 10:00:00"), ts("2026-11-09 10:20:00"))
    b.registrar("xyz", ts("2026-11-09 10:00:00"), ts("2026-11-09 10:00:30"))
    h = dados.resumo_hoje(b, date(2026, 11, 9), dirs=[apps])
    assert h == [
        {"app": "steam", "nome": "Steam", "icone": "steam", "segundos": 1200, "texto": "20 min"},
        {"app": "xyz", "nome": "xyz", "icone": "application-x-executable", "segundos": 30, "texto": "<1 min"},
    ]


def test_nome_do_desktop_em_pt_br(tmp_path):
    (tmp_path / "org.kde.dolphin.desktop").write_text(
        "[Desktop Entry]\nName=Dolphin\nName[pt_BR]=Gerenciador de arquivos\nIcon=system-file-manager\n", encoding="utf-8")
    assert dados.nome_e_icone("org.kde.dolphin", [tmp_path]) == ("Gerenciador de arquivos", "system-file-manager")


def test_apps_conhecidos_junta_banco_e_config(tmp_path):
    b = Banco(tmp_path / "f.db")
    b.registrar("firefox", 100, 200)
    cfg = Config(sempre={"steam"}, segundo_plano=set(), limites_min={"firefox": 30}, sem_autotile={"blender"})
    apps = {a["app"]: a for a in dados.apps_conhecidos(b, cfg, dirs=[])}
    assert set(apps) == {"firefox", "steam", "blender"}
    assert apps["firefox"]["limite_min"] == 30 and apps["firefox"]["prioridade"] == "normal" and apps["firefox"]["autotile"]
    assert apps["steam"]["prioridade"] == "sempre" and apps["steam"]["limite_min"] is None
    assert apps["blender"]["autotile"] is False


def test_ignoreclass_padrao_igual_ao_do_primeiro_login():
    script = (RAIZ / "packages/xinguos/xinguos-desktop/xinguos-primeiro-login").read_text(encoding="utf-8")
    m = re.search(r'--key ignoreClass "([^"]+)"', script)
    assert m, "ignoreClass não encontrado no xinguos-primeiro-login"
    assert m.group(1).split(",") == dados.IGNORE_PADRAO


def test_aplicar_mudancas_salva_toml_e_ignoreclass(tmp_path):
    usu = tmp_path / "foco.toml"
    cfg = Config(sempre=set(), segundo_plano={"org.qbittorrent.qBittorrent"}, limites_min={"steam": 120}, sem_autotile=set())
    gravado = []
    dados.aplicar_mudancas(cfg, [
        {"app": "org.mozilla.firefox", "prioridade": "segundo_plano", "limite_min": 60, "autotile": False},
        {"app": "steam", "prioridade": "sempre", "limite_min": 0, "autotile": True},
        {"app": "org.qbittorrent.qBittorrent", "prioridade": "normal", "limite_min": 0, "autotile": True},
    ], usu, lambda cmd: gravado.append(cmd) or 0)
    lido, avisos = carregar(tmp_path / "nao", usu)
    assert avisos == []
    assert lido.sempre == {"steam"}
    assert lido.segundo_plano == {"org.mozilla.firefox"}
    assert lido.limites_min == {"org.mozilla.firefox": 60}
    assert lido.sem_autotile == {"org.mozilla.firefox"}
    assert len(gravado) == 1
    cmd = gravado[0]
    assert cmd[:7] == ["kwriteconfig6", "--file", "kwinrc", "--group", "Script-krohnkite", "--key", "ignoreClass"]
    lista = cmd[7].split(",")
    assert lista[:len(dados.IGNORE_PADRAO)] == dados.IGNORE_PADRAO
    # o id do app e o nome curto (classe da janela costuma ser só "firefox")
    assert "org.mozilla.firefox" in lista and "firefox" in lista


@pytest.mark.qt
def test_qml_carrega(tmp_path):
    pytest.importorskip("PySide6")
    os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
    from xinguos_foco_painel.__main__ import montar

    app, engine, avisos = montar(db=tmp_path / "f.db", sistema=tmp_path / "s.toml", usuario=tmp_path / "u.toml")
    assert engine.rootObjects(), avisos
    assert avisos == []
