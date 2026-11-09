"""Lógica do daemon sem D-Bus: foco → intervalos + pesos; tick periódico → ociosidade, limites, limpeza."""
from __future__ import annotations

import json
import logging
import time
from datetime import date, datetime
from pathlib import Path
from typing import Callable

from .apps import nome_e_icone
from .banco import Banco
from .config import carregar, peso
from .limites import limites_estourados
from .prioridade import Aplicador, scope_do_pid
from .rastreador import Rastreador

log = logging.getLogger(__name__)


class Nucleo:
    def __init__(self, banco: Banco, sistema: Path, usuario: Path, executar: Callable[[list[str]], int],
                 proc: Path = Path("/proc"), agora: Callable[[], float] = time.time,
                 dirs_apps: list[Path] | None = None):
        self.banco, self.sistema, self.usuario = banco, Path(sistema), Path(usuario)
        self.proc, self.agora, self.dirs_apps = proc, agora, dirs_apps
        self.rastreador = Rastreador(banco)
        self.aplicador = Aplicador(executar)
        self.units: dict[str, str] = {}          # unit → app (todas as já vistas)
        self.atual: tuple[str, str | None] | None = None
        self.avisados: tuple[date, set[str]] = (self._hoje(), set())
        self.ultima_purga: date | None = None
        self._carregar_config()

    def _hoje(self) -> date:
        return datetime.fromtimestamp(self.agora()).date()

    def _mtimes(self):
        def m(p: Path):
            try:
                return p.stat().st_mtime_ns
            except OSError:
                return None
        return m(self.sistema), m(self.usuario)

    def _carregar_config(self) -> None:
        self.mtimes = self._mtimes()
        self.cfg, avisos = carregar(self.sistema, self.usuario)
        for a in avisos:
            log.warning("%s", a)

    def foco(self, desktop: str, classe: str, pid: str) -> None:
        app = (desktop or classe or "").strip()
        if not app:
            return
        self.rastreador.foco(app, self.agora())
        unit = scope_do_pid(int(pid), self.proc) if pid.strip().isdigit() else None
        if self.atual == (app, unit):
            return
        if self.atual:
            app_ant, unit_ant = self.atual
            if unit_ant and unit_ant != unit:
                self.aplicador.aplicar(unit_ant, peso(app_ant, self.cfg, em_foco=False))
        if unit:
            self.units[unit] = app
            self.aplicador.aplicar(unit, peso(app, self.cfg, em_foco=True))
        self.atual = (app, unit)

    def recarregar(self) -> None:
        self._carregar_config()
        for unit, app in self.units.items():
            em_foco = self.atual is not None and self.atual[1] == unit
            self.aplicador.aplicar(unit, peso(app, self.cfg, em_foco=em_foco))

    def totais(self) -> list[tuple[str, int]]:
        return self.banco.totais_do_dia(self._hoje())

    def totais_json(self) -> str:
        return json.dumps([{"app": a, "segundos": s} for a, s in self.totais()], ensure_ascii=False)

    def tick(self, ocioso_seg: float, avisar: Callable[[str, str, int, int], None]) -> None:
        agora = self.agora()
        self.rastreador.ocioso(ocioso_seg, agora)
        self.rastreador.checkpoint(agora)
        if self._mtimes() != self.mtimes:
            log.info("foco.toml mudou: recarregando")
            self.recarregar()
        hoje = self._hoje()
        if self.avisados[0] != hoje:
            self.avisados = (hoje, set())
        totais = self.totais()
        usados = dict(totais)
        for app in limites_estourados(totais, self.cfg.limites_min, self.avisados[1]):
            self.avisados[1].add(app)
            nome, _ = nome_e_icone(app, self.dirs_apps)
            try:
                avisar(app, nome, usados[app] // 60, self.cfg.limites_min[app])
            except Exception as e:  # noqa: BLE001
                log.warning("não consegui avisar o limite de %s: %s", app, e)
        if self.ultima_purga != hoje:
            self.ultima_purga = hoje
            apagados = self.banco.purgar(90)
            if apagados:
                log.info("limpeza: %d intervalos com mais de 90 dias apagados", apagados)

    def encerrar(self) -> None:
        self.rastreador.encerrar(self.agora())
