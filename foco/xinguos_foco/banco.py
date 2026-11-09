"""Banco SQLite local dos intervalos de uso (nada sai do PC)."""
from __future__ import annotations

import logging
import os
import sqlite3
import time
from datetime import date, datetime, timedelta
from datetime import time as hora
from pathlib import Path
from typing import Callable

log = logging.getLogger(__name__)

_ESQUEMA = """
CREATE TABLE IF NOT EXISTS intervalos (
    app TEXT NOT NULL,
    inicio REAL NOT NULL,
    fim REAL NOT NULL
);
CREATE INDEX IF NOT EXISTS intervalos_fim ON intervalos (fim);
"""


def _limites_do_dia(dia: date) -> tuple[float, float]:
    """Começo e fim do dia no fuso local, em segundos desde a época."""
    comeco = datetime.combine(dia, hora.min).timestamp()
    fim = datetime.combine(dia + timedelta(days=1), hora.min).timestamp()
    return comeco, fim


class Banco:
    def __init__(self, caminho: Path, agora: Callable[[], float] = time.time):
        self.caminho = Path(caminho)
        self.agora = agora
        self.caminho.parent.mkdir(parents=True, exist_ok=True)
        try:
            self.con = self._abrir()
        except sqlite3.DatabaseError as e:
            carimbo = datetime.fromtimestamp(self.agora()).strftime("%Y%m%d-%H%M%S")
            destino = self.caminho.with_name(f"{self.caminho.name}.corrompido-{carimbo}")
            log.warning("banco %s corrompido (%s): renomeado para %s", self.caminho, e, destino.name)
            os.replace(self.caminho, destino)
            for extra in ("-wal", "-shm", "-journal"):
                resto = self.caminho.with_name(self.caminho.name + extra)
                if resto.exists():
                    resto.unlink()
            self.con = self._abrir()

    def _abrir(self) -> sqlite3.Connection:
        con = sqlite3.connect(self.caminho)
        try:
            con.executescript(_ESQUEMA)
            con.execute("SELECT count(*) FROM intervalos").fetchone()
        except sqlite3.DatabaseError:
            con.close()
            raise
        return con

    def registrar(self, app: str, inicio: float, fim: float) -> None:
        if not app or fim <= inicio:
            return
        with self.con:
            self.con.execute("INSERT INTO intervalos (app, inicio, fim) VALUES (?, ?, ?)", (app, inicio, fim))

    def _por_app(self, comeco: float, fim: float) -> list[tuple[str, int]]:
        linhas = self.con.execute(
            """SELECT app, SUM(MIN(fim, :f) - MAX(inicio, :c)) AS s
               FROM intervalos WHERE fim > :c AND inicio < :f
               GROUP BY app ORDER BY s DESC, app""",
            {"c": comeco, "f": fim},
        ).fetchall()
        return [(app, int(round(s))) for app, s in linhas if s and s > 0]

    def totais_do_dia(self, dia: date) -> list[tuple[str, int]]:
        return self._por_app(*_limites_do_dia(dia))

    def totais_por_dia(self, ate: date, dias: int = 7) -> dict[date, int]:
        resultado: dict[date, int] = {}
        for i in range(dias - 1, -1, -1):
            dia = ate - timedelta(days=i)
            resultado[dia] = sum(s for _, s in self.totais_do_dia(dia))
        return resultado

    def apps(self) -> list[str]:
        return [a for (a,) in self.con.execute("SELECT DISTINCT app FROM intervalos ORDER BY app")]

    def purgar(self, manter_dias: int = 90) -> int:
        corte = self.agora() - manter_dias * 86400
        with self.con:
            cur = self.con.execute("DELETE FROM intervalos WHERE fim < ?", (corte,))
        return cur.rowcount

    def fechar(self) -> None:
        self.con.close()
