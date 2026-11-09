from datetime import date, datetime

from xinguos_foco.rastreador import Rastreador


class BancoFalso:
    def __init__(self):
        self.intervalos = []

    def registrar(self, app, inicio, fim):
        if app and fim > inicio:
            self.intervalos.append((app, inicio, fim))


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
