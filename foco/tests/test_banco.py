import time
from datetime import date, datetime, timedelta

from xinguos_foco.banco import Banco


def ts(texto):
    return datetime.fromisoformat(texto).timestamp()


def test_banco_corrompido_e_renomeado(tmp_path):
    db = tmp_path / "foco.db"
    db.write_bytes(b"isto nao e sqlite " * 200)
    b = Banco(db, agora=lambda: ts("2026-11-09 10:00:00"))
    b.registrar("firefox", ts("2026-11-09 09:00:00"), ts("2026-11-09 09:10:00"))
    assert b.totais_do_dia(date(2026, 11, 9)) == [("firefox", 600)]
    assert (tmp_path / "foco.db.corrompido-20261109-100000").exists()


def test_intervalo_que_atravessa_meia_noite_divide_entre_os_dias(tmp_path):
    b = Banco(tmp_path / "foco.db")
    b.registrar("steam", ts("2026-11-08 23:30:00"), ts("2026-11-09 00:45:00"))
    assert b.totais_do_dia(date(2026, 11, 8)) == [("steam", 1800)]
    assert b.totais_do_dia(date(2026, 11, 9)) == [("steam", 2700)]
    semana = b.totais_por_dia(date(2026, 11, 9), dias=7)
    assert list(semana) == [date(2026, 11, 3) + timedelta(days=i) for i in range(7)]
    assert semana[date(2026, 11, 8)] == 1800 and semana[date(2026, 11, 9)] == 2700
    assert semana[date(2026, 11, 7)] == 0


def test_totais_ordenados_do_maior_para_o_menor(tmp_path):
    b = Banco(tmp_path / "foco.db")
    b.registrar("a", ts("2026-11-09 10:00:00"), ts("2026-11-09 10:01:00"))
    b.registrar("b", ts("2026-11-09 11:00:00"), ts("2026-11-09 11:30:00"))
    b.registrar("a", ts("2026-11-09 12:00:00"), ts("2026-11-09 12:02:00"))
    assert b.totais_do_dia(date(2026, 11, 9)) == [("b", 1800), ("a", 180)]


def test_purgar_90_dias(tmp_path):
    agora = ts("2026-11-09 12:00:00")
    b = Banco(tmp_path / "foco.db", agora=lambda: agora)
    b.registrar("velho", agora - 100 * 86400, agora - 100 * 86400 + 60)
    b.registrar("novo", agora - 10 * 86400, agora - 10 * 86400 + 60)
    assert b.purgar(90) == 1
    hoje = date(2026, 11, 9)
    assert b.totais_do_dia(hoje - timedelta(days=10)) == [("novo", 60)]
    assert b.totais_do_dia(hoje - timedelta(days=100)) == []


def test_intervalo_vazio_ou_invertido_ignorado(tmp_path):
    b = Banco(tmp_path / "foco.db")
    t = ts("2026-11-09 10:00:00")
    b.registrar("x", t, t)
    b.registrar("x", t, t - 5)
    b.registrar("", t, t + 5)
    assert b.totais_do_dia(date(2026, 11, 9)) == []


def test_apps_registrados(tmp_path):
    b = Banco(tmp_path / "foco.db")
    t = time.time()
    b.registrar("b", t, t + 1)
    b.registrar("a", t, t + 1)
    assert b.apps() == ["a", "b"]
