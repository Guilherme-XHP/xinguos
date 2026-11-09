"""Máquina de estados do foco: transforma eventos de foco e ociosidade em intervalos."""
from __future__ import annotations

LIMITE_OCIOSO = 120  # segundos parado até deixar de contar (spec 7.2)


class Rastreador:
    def __init__(self, banco, limite_ocioso: float = LIMITE_OCIOSO):
        self.banco = banco
        self.limite = limite_ocioso
        self.app: str | None = None       # app em foco (mesmo pausado)
        self.inicio: float | None = None  # None = pausado ou sem app
        self.pausado = False

    def _fechar(self, fim: float) -> None:
        if self.app and self.inicio is not None:
            self.banco.registrar(self.app, self.inicio, max(fim, self.inicio))
        self.inicio = None

    def foco(self, app: str, agora: float) -> None:
        if not app:
            return
        if app == self.app and not self.pausado:
            return
        self._fechar(agora)
        self.app, self.inicio, self.pausado = app, agora, False

    def ocioso(self, segundos: float, agora: float) -> None:
        if segundos >= self.limite:
            if not self.pausado:
                self._fechar(agora - segundos)
                self.pausado = True
        elif self.pausado:
            self.pausado = False
            if self.app:
                self.inicio = agora - max(segundos, 0)

    def encerrar(self, agora: float) -> None:
        if not self.pausado:
            self._fechar(agora)
        self.app, self.inicio, self.pausado = None, None, False

    def checkpoint(self, agora: float) -> None:
        """Grava o pedaço em andamento (para totais e limites ficarem em dia)."""
        if not self.pausado and self.app and self.inicio is not None and agora > self.inicio:
            self._fechar(agora)
            self.inicio = agora
