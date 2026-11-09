import asyncio
import json

import pytest

pytestmark = pytest.mark.dbus


async def chamar(bus, membro, assinatura="", corpo=None):
    from dbus_fast import Message, MessageType
    r = await bus.call(Message(destination="org.xinguos.Foco", path="/org/xinguos/Foco", interface="org.xinguos.Foco",
                               member=membro, signature=assinatura, body=corpo or []))
    assert r.message_type == MessageType.METHOD_RETURN, r.body
    return r.body


async def esperar_nome(bus):
    from dbus_fast import Message, MessageType
    for _ in range(100):
        r = await bus.call(Message(destination="org.freedesktop.DBus", path="/org/freedesktop/DBus",
                                   interface="org.freedesktop.DBus", member="NameHasOwner", signature="s",
                                   body=["org.xinguos.Foco"]))
        if r.message_type == MessageType.METHOD_RETURN and r.body[0]:
            return
        await asyncio.sleep(0.1)
    raise AssertionError("serviço não apareceu no barramento")


def test_servico_dbus(tmp_path):
    from dbus_fast.aio import MessageBus

    from xinguos_foco import servico

    async def main():
        parar = asyncio.Event()
        tarefa = asyncio.create_task(servico.rodar(tmp_path / "f.db", tmp_path / "sis.toml", tmp_path / "u.toml",
                                                   parar=parar, intervalo=0.2))
        cli = await MessageBus().connect()
        await esperar_nome(cli)
        await chamar(cli, "Foco", "sss", ["org.kde.dolphin", "dolphin", "999999"])  # pid inexistente
        await asyncio.sleep(1.1)
        await chamar(cli, "Foco", "sss", ["firefox", "firefox", "999999"])
        await chamar(cli, "Foco", "sss", ["", "", "lixo"])
        await chamar(cli, "Recarregar")
        (totais,) = await chamar(cli, "Totais")
        apps = [t["app"] for t in json.loads(totais)]
        assert "org.kde.dolphin" in apps
        parar.set()
        assert await asyncio.wait_for(tarefa, 10) == 0
        cli.disconnect()

    asyncio.run(main())
