import json
from datetime import datetime

from xinguos_foco.banco import Banco
from xinguos_foco.nucleo import Nucleo

CG = "0::/user.slice/user-1000.slice/user@1000.service/app.slice/{}\n"


def montar(tmp_path, toml=""):
    proc = tmp_path / "proc"
    for pid, unit in ((10, "app-dolphin@1.scope"), (20, "app-firefox@2.scope"), (30, "app-qbit@3.scope")):
        (proc / str(pid)).mkdir(parents=True)
        (proc / str(pid) / "cgroup").write_text(CG.format(unit))
    (proc / "40").mkdir()
    (proc / "40" / "cgroup").write_text("0::/user.slice/user-1000.slice/session-2.scope\n")
    usu = tmp_path / "foco.toml"
    usu.write_text(toml, encoding="utf-8")
    relogio = [datetime(2026, 11, 9, 10).timestamp()]
    chamadas = []
    n = Nucleo(Banco(tmp_path / "f.db", agora=lambda: relogio[0]), tmp_path / "sis.toml", usu,
               executar=lambda c: chamadas.append((c[4], c[5])) or 0, proc=proc, agora=lambda: relogio[0], dirs_apps=[])
    return n, chamadas, relogio


def test_foco_da_peso_500_e_devolve_o_anterior(tmp_path):
    n, ch, t = montar(tmp_path)
    n.foco("org.kde.dolphin", "dolphin", "10")
    n.foco("firefox", "firefox", "20")
    assert ch == [("app-dolphin@1.scope", "CPUWeight=500"), ("app-dolphin@1.scope", "CPUWeight=100"),
                  ("app-firefox@2.scope", "CPUWeight=500")]


def test_segundo_plano_fica_25_mesmo_em_foco(tmp_path):
    n, ch, t = montar(tmp_path, '[prioridades]\nsegundo_plano = ["qbit"]\nsempre = ["firefox"]\n')
    n.foco("qbit", "", "30")
    n.foco("firefox", "", "20")
    n.foco("org.kde.dolphin", "", "10")
    # o anterior já tinha o peso de fora de foco (25 e 1000): nenhuma chamada repetida
    assert ch == [("app-qbit@3.scope", "CPUWeight=25"), ("app-firefox@2.scope", "CPUWeight=1000"),
                  ("app-dolphin@1.scope", "CPUWeight=500")]


def test_mesma_janela_e_pid_ruim_nao_chamam_systemctl(tmp_path):
    n, ch, t = montar(tmp_path)
    n.foco("firefox", "", "20")
    n.foco("firefox", "", "20")
    n.foco("konsole", "", "40")       # session.slice: sem scope
    n.foco("fantasma", "", "999999")  # processo morto
    n.foco("lixo", "", "abc")
    n.foco("", "", "20")              # sem nome: ignorado
    assert ch == [("app-firefox@2.scope", "CPUWeight=500"), ("app-firefox@2.scope", "CPUWeight=100")]


def test_totais_e_limite_avisa_uma_vez(tmp_path):
    n, ch, t = montar(tmp_path, '[limites]\n"firefox" = 1\n')
    avisos = []
    n.foco("firefox", "", "20")
    t[0] += 30
    assert n.tick(0, avisar=lambda app, nome, usado, lim: avisos.append((app, usado, lim))) is None
    assert avisos == []
    t[0] += 40
    n.tick(0, avisar=lambda app, nome, usado, lim: avisos.append((app, usado, lim)))
    t[0] += 30
    n.tick(0, avisar=lambda app, nome, usado, lim: avisos.append((app, usado, lim)))
    assert avisos == [("firefox", 1, 1)]
    assert json.loads(n.totais_json()) == [{"app": "firefox", "segundos": 100}]


def test_recarregar_reaplica_pesos(tmp_path):
    n, ch, t = montar(tmp_path)
    n.foco("qbit", "", "30")
    n.foco("firefox", "", "20")
    ch.clear()
    n.usuario.write_text('[prioridades]\nsegundo_plano = ["qbit"]\n', encoding="utf-8")
    n.recarregar()
    assert ch == [("app-qbit@3.scope", "CPUWeight=25")]


def test_suspensao_nao_conta_como_uso(tmp_path):
    n, ch, t = montar(tmp_path)
    nada = lambda *a: None  # noqa: E731
    n.foco("firefox", "", "20")
    t[0] += 30
    n.tick(0, avisar=nada)
    t[0] += 8 * 3600       # PC suspenso: nenhum tick por 8 h, ociosidade volta zerada
    n.tick(0, avisar=nada)
    t[0] += 30
    n.tick(0, avisar=nada)
    assert json.loads(n.totais_json()) == [{"app": "firefox", "segundos": 60}]
