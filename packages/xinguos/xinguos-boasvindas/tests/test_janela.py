import os
from pathlib import Path

import pytest

RAIZ = Path(__file__).resolve().parents[4]
pytestmark = pytest.mark.qt


@pytest.fixture(autouse=True)
def qt(monkeypatch):
    pytest.importorskip("PySide6")
    monkeypatch.setenv("QT_QPA_PLATFORM", "offscreen")


def test_qml_carrega(tmp_path, monkeypatch):
    import xinguos_boasvindas.__main__ as m
    monkeypatch.setattr(m, "LOGO", RAIZ / "packages/xinguos/xinguos-branding/logo/xinguos.svg")
    app, engine, avisos = m.montar(estado=tmp_path)
    assert engine.rootObjects(), avisos
    assert avisos == []


def test_primeira_vez_ja_visto_nao_abre(tmp_path, monkeypatch):
    import xinguos_boasvindas.__main__ as m
    from xinguos_boasvindas.estado import marcar_visto
    marcar_visto(tmp_path)
    monkeypatch.setattr(m, "dir_estado", lambda: tmp_path)
    monkeypatch.setattr(m, "montar", lambda *a, **k: pytest.fail("não devia abrir a janela"))
    assert m.main(["--primeira-vez"]) == 0


def test_instalar_grava_o_roteiro_e_abre_o_konsole(tmp_path, monkeypatch):
    import xinguos_boasvindas.__main__ as m
    abertos = []
    monkeypatch.setenv("XDG_RUNTIME_DIR", str(tmp_path))
    monkeypatch.setattr(m.subprocess, "Popen", lambda cmd: abertos.append(cmd))
    b = m.Backend(tmp_path)
    assert b.instalar(["spotify"]) == "Instalação aberta no Konsole."
    script = tmp_path / "xinguos-boasvindas.sh"
    assert "com.spotify.Client" in script.read_text(encoding="utf-8")
    assert abertos == [["konsole", "--hold", "-e", "bash", str(script)]]
    assert b.instalar([]) == "Nada marcado."
    assert "desconhecidos" in b.instalar(["nao-existe"])


def test_mostrar_ao_iniciar(tmp_path):
    import xinguos_boasvindas.__main__ as m
    b = m.Backend(tmp_path)
    assert b.mostrarAoIniciar()
    b.definirMostrarAoIniciar(False)
    assert not b.mostrarAoIniciar()
    b.definirMostrarAoIniciar(True)
    assert b.mostrarAoIniciar()


def test_sessao_e_modo_do_gaming(tmp_path, monkeypatch):
    import subprocess

    import xinguos_boasvindas.__main__ as m
    chamadas = []

    class R:
        def __init__(self, out="", rc=0):
            self.stdout, self.returncode, self.stderr = out, rc, ""

    def falso(cmd, **k):
        chamadas.append(cmd)
        if cmd[1:] == ["--status"]:
            return R("padrao=gaming" + chr(10) + "modo=compativel" + chr(10))
        return R()
    monkeypatch.setattr(m.shutil, "which", lambda c: "/usr/bin/" + c)
    monkeypatch.setattr(m.subprocess, "run", falso)
    b = m.Backend(tmp_path)
    assert b.sessao() == {"disponivel": True, "padrao": "gaming", "modo": "compativel"}
    assert b.definirPadrao("desktop") == "Ao ligar: desktop."
    assert b.definirModo("completo") == "Gaming Mode: completo."
    assert ["xinguos-session-select", "--default", "desktop"] in chamadas
    assert ["xinguos-session-select", "--modo", "completo"] in chamadas
    assert "inválid" in b.definirModo("turbo")
    monkeypatch.setattr(m.shutil, "which", lambda c: None)
    assert b.sessao()["disponivel"] is False
