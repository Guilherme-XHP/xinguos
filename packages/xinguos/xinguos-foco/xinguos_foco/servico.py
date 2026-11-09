"""Cola D-Bus do daemon: serviço org.xinguos.Foco no barramento de sessão + laço de 30 s.

(Sem "from __future__ import annotations": o dbus-fast lê as assinaturas "s" das anotações.)
"""
import asyncio
import logging
import os
import shutil
import signal
import subprocess
import time
from pathlib import Path

from dbus_fast import BusType, Message, MessageType
from dbus_fast.aio import MessageBus
from dbus_fast.constants import NameFlag, RequestNameReply
from dbus_fast.service import ServiceInterface, method

from .banco import Banco, caminho_padrao
from .config import caminhos_padrao
from .nucleo import Nucleo
from .rastreador import LIMITE_OCIOSO

log = logging.getLogger(__name__)

NOME = "org.xinguos.Foco"
CAMINHO = "/org/xinguos/Foco"
INTERVALO = 30


class Interface(ServiceInterface):
    def __init__(self, nucleo: Nucleo):
        super().__init__(NOME)
        self.nucleo = nucleo

    @method()
    def Foco(self, desktop: "s", classe: "s", pid: "s"):  # noqa: N802,F821
        try:
            self.nucleo.foco(desktop, classe, pid)
        except Exception:  # noqa: BLE001 — um evento ruim nunca derruba o daemon
            log.exception("erro tratando o foco de %r/%r/%r", desktop, classe, pid)

    @method()
    def Recarregar(self):  # noqa: N802
        try:
            self.nucleo.recarregar()
        except Exception:  # noqa: BLE001
            log.exception("erro ao recarregar o foco.toml")

    @method()
    def Totais(self) -> "s":  # noqa: N802,F821
        return self.nucleo.totais_json()


def _executar(cmd: list[str]) -> int:
    r = subprocess.run(cmd, stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE,
                       timeout=5, check=False)
    if r.returncode != 0 and r.stderr:
        log.debug("%s: %s", " ".join(cmd), r.stderr.decode(errors="replace").strip())
    return r.returncode


class Ociosidade:
    """Quantos segundos o usuário está parado.

    No Wayland, o KWin só informa isso pelo protocolo ext-idle-notify, que o swayidle usa
    (e respeita inibidores: jogo ou vídeo que segura a tela não conta como parado).
    Sem swayidle (ou no X11), pergunta ao org.freedesktop.ScreenSaver (o do KDE responde em ms).
    """

    def __init__(self, bus: MessageBus, ao_mudar):
        self.bus = bus
        self.ao_mudar = ao_mudar
        self.parado_desde = None
        self.proc = None
        self.leitor = None

    async def iniciar(self) -> None:
        exe = shutil.which("swayidle")
        if not exe or not os.environ.get("WAYLAND_DISPLAY"):
            log.info("ociosidade: sem swayidle/Wayland, usando org.freedesktop.ScreenSaver")
            return
        try:
            self.proc = await asyncio.create_subprocess_exec(
                exe, "timeout", str(LIMITE_OCIOSO), "echo ocioso", "resume", "echo voltou",
                stdin=subprocess.DEVNULL, stdout=subprocess.PIPE)
        except OSError as e:
            log.warning("ociosidade: swayidle não abriu (%s); usando org.freedesktop.ScreenSaver", e)
            self.proc = None
            return
        self.leitor = asyncio.create_task(self._ler())

    async def _ler(self) -> None:
        async for linha in self.proc.stdout:
            evento = linha.decode(errors="replace").strip()
            if evento == "ocioso":
                self.parado_desde = time.time() - LIMITE_OCIOSO
            elif evento == "voltou":
                self.parado_desde = None
            else:
                continue
            try:
                self.ao_mudar(await self.segundos())
            except Exception:  # noqa: BLE001
                log.exception("erro tratando ociosidade")
        codigo = await self.proc.wait()
        log.warning("ociosidade: swayidle terminou (código %s); usando org.freedesktop.ScreenSaver", codigo)
        self.proc = None
        self.parado_desde = None

    async def segundos(self) -> float:
        if self.proc is not None:
            return 0.0 if self.parado_desde is None else time.time() - self.parado_desde
        try:
            r = await asyncio.wait_for(self.bus.call(Message(
                destination="org.freedesktop.ScreenSaver", path="/ScreenSaver",
                interface="org.freedesktop.ScreenSaver", member="GetSessionIdleTime")), 2)
        except (asyncio.TimeoutError, OSError):
            return 0.0
        if r.message_type != MessageType.METHOD_RETURN or not r.body:
            return 0.0
        return float(r.body[0]) / 1000.0

    def parar(self) -> None:
        if self.proc is not None and self.proc.returncode is None:
            self.proc.terminate()
        if self.leitor is not None:
            self.leitor.cancel()


async def notificar(bus: MessageBus, nome: str, usado: int, limite: int) -> None:
    r = await bus.call(Message(
        destination="org.freedesktop.Notifications", path="/org/freedesktop/Notifications",
        interface="org.freedesktop.Notifications", member="Notify", signature="susssasa{sv}i",
        body=["XInguOS Foco", 0, "dialog-information", f"Limite de {nome}",
              f"Você usou {nome} por {usado} min hoje (limite: {limite} min).", [], {}, 10000]))
    if r.message_type != MessageType.METHOD_RETURN:
        log.warning("notificação do limite de %s falhou: %s", nome, r.body)


async def rodar(db=None, sistema=None, usuario=None, parar=None, intervalo: float = INTERVALO) -> int:
    sis_padrao, usu_padrao = caminhos_padrao()
    banco = Banco(db or caminho_padrao())
    nucleo = Nucleo(banco, sistema or sis_padrao, usuario or usu_padrao, executar=_executar)
    bus = await MessageBus(bus_type=BusType.SESSION).connect()
    bus.export(CAMINHO, Interface(nucleo))
    if await bus.request_name(NOME, NameFlag.DO_NOT_QUEUE) != RequestNameReply.PRIMARY_OWNER:
        log.error("%s já está rodando nesta sessão", NOME)
        bus.disconnect()
        banco.fechar()
        return 1
    log.info("xinguos-foco no ar (banco %s)", banco.caminho)

    parar = parar or asyncio.Event()
    laco = asyncio.get_running_loop()
    for sinal in (signal.SIGTERM, signal.SIGINT):
        try:
            laco.add_signal_handler(sinal, parar.set)
        except (NotImplementedError, RuntimeError, ValueError):
            pass

    pendentes = set()

    def avisar(app: str, nome: str, usado: int, limite: int) -> None:
        t = laco.create_task(notificar(bus, nome, usado, limite))
        pendentes.add(t)
        t.add_done_callback(pendentes.discard)

    ocio = Ociosidade(bus, lambda s: nucleo.rastreador.ocioso(s, time.time()))
    await ocio.iniciar()
    while not parar.is_set():
        try:
            await asyncio.wait_for(parar.wait(), intervalo)
        except asyncio.TimeoutError:
            pass
        try:
            nucleo.tick(await ocio.segundos(), avisar)
        except Exception:  # noqa: BLE001
            log.exception("erro no laço periódico")
    ocio.parar()
    nucleo.encerrar()
    banco.fechar()
    bus.disconnect()
    return 0
