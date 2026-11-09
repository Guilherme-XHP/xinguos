from datetime import date, datetime

from xinguos_foco.rastreador import Rastreador


class BancoFalso:
    def __init__(self):
        self.intervalos = []

    def registrar(self, app, inicio, fim):
        if app and fim > inicio:
            self.intervalos.append((app, inicio, fim))

    def cortar(self, app, desde):
        cortados = [(a, i, min(f, desde) if a == app else f) for a, i, f in self.intervalos]
        self.intervalos = [(a, i, f) for a, i, f in cortados if f > i]


def test_foco_no_mesmo_app_nao_duplica_intervalo():
    b = BancoFalso()
    r = Rastreador(b)
    r.foco("firefox", 100)
    r.foco("firefox", 150)
    r.foco("firefox", 160)
    r.encerrar(200)
    assert b.intervalos == [("firefox", 100, 200)]


def test_trocar_de_app_fecha_o_anterior():
    b = BancoFalso()
    r = Rastreador(b)
    r.foco("firefox", 100)
    r.foco("dolphin", 130)
    r.encerrar(140)
    assert b.intervalos == [("firefox", 100, 130), ("dolphin", 130, 140)]


def test_ocioso_fecha_em_agora_menos_ocioso_e_reabre_ao_voltar():
    b = BancoFalso()
    r = Rastreador(b)
    r.foco("firefox", 0)
    r.ocioso(60, 100)          # abaixo do limite: nada muda
    assert b.intervalos == []
    r.ocioso(300, 400)         # parado desde 100
    assert b.intervalos == [("firefox", 0, 100)]
    r.ocioso(330, 430)         # continua parado: não fecha de novo
    assert b.intervalos == [("firefox", 0, 100)]
    r.ocioso(2, 500)           # voltou: reabre o último app a partir de 498
    r.encerrar(600)
    assert b.intervalos == [("firefox", 0, 100), ("firefox", 498, 600)]


def test_foco_durante_ociosidade_retoma():
    b = BancoFalso()
    r = Rastreador(b)
    r.foco("firefox", 0)
    r.ocioso(300, 400)
    r.foco("dolphin", 410)     # trocar de janela é atividade
    r.encerrar(420)
    assert b.intervalos == [("firefox", 0, 100), ("dolphin", 410, 420)]


def test_ociosidade_que_atravessa_a_meia_noite_nao_fica_negativa(tmp_path):
    from xinguos_foco.banco import Banco
    meia_noite = datetime(2026, 11, 9).timestamp()
    b = Banco(tmp_path / "f.db")
    r = Rastreador(b)
    r.foco("steam", meia_noite - 600)
    r.ocioso(900, meia_noite + 300)    # parado desde 23:50
    r.ocioso(1, meia_noite + 400)
    r.encerrar(meia_noite + 460)
    assert b.totais_do_dia(date(2026, 11, 8)) == []
    assert b.totais_do_dia(date(2026, 11, 9)) == [("steam", 61)]


def test_checkpoint_grava_o_pedaco_em_andamento():
    b = BancoFalso()
    r = Rastreador(b)
    r.foco("firefox", 0)
    r.checkpoint(30)
    r.checkpoint(60)
    r.foco("firefox", 70)      # mesmo app: não duplica
    r.encerrar(90)
    assert b.intervalos == [("firefox", 0, 30), ("firefox", 30, 60), ("firefox", 60, 90)]
    assert sum(f - i for _, i, f in b.intervalos) == 90


def test_checkpoint_pausado_nao_grava():
    b = BancoFalso()
    r = Rastreador(b)
    r.foco("firefox", 0)
    r.ocioso(120, 200)
    r.checkpoint(250)
    assert b.intervalos == [("firefox", 0, 80)]


def test_ocioso_depois_de_checkpoint_recua_o_que_ja_foi_gravado(tmp_path):
    from xinguos_foco.banco import Banco
    b = Banco(tmp_path / "f.db")
    base = datetime(2026, 11, 9, 10).timestamp()
    r = Rastreador(b)
    r.foco("firefox", base)
    for t in (30, 60, 90, 120, 150, 180, 210):   # ticks de 30 s; parou em base+100
        r.checkpoint(base + t)
    r.ocioso(120, base + 220)
    r.checkpoint(base + 250)
    assert b.totais_do_dia(date(2026, 11, 9)) == [("firefox", 100)]
