"""xinguos-boasvindas: janela "Bem-vindo ao XInguOS" (spec 5.3).

--primeira-vez: chamado pelo autostart; só abre se ainda não foi visto (e marca como visto).
"""
import os
import shutil
import subprocess
import sys
from pathlib import Path

from PySide6.QtCore import QObject, QUrl, Slot
from PySide6.QtGui import QGuiApplication, QIcon
from PySide6.QtQml import QQmlApplicationEngine

from .catalogo import ITENS
from .estado import MARCA, aviso_hw, dir_estado, ja_visto, marcar_visto
from .roteiro import roteiro

QML = Path(__file__).resolve().with_name("Main.qml")
LOGO = Path(os.environ.get("XINGUOS_LOGO", "/usr/share/pixmaps/xinguos.svg"))
CACHORRO = Path(os.environ.get("XINGUOS_CACHORRO", "/usr/share/xinguos/easter-egg/cachorro.jpg"))


def _url(caminho: Path) -> str:
    return QUrl.fromLocalFile(str(caminho)).toString() if caminho.is_file() else ""


class Backend(QObject):
    def __init__(self, estado: Path):
        super().__init__()
        self.estado = estado

    @Slot(result="QVariantList")
    def itens(self):
        return [{"id": i.id, "nome": i.nome, "descricao": i.descricao, "marcado": i.marcado, "aviso": i.aviso}
                for i in ITENS]

    @Slot(result=str)
    def avisoHw(self):  # noqa: N802
        try:
            r = subprocess.run(["xinguos-hwdetect", "--detectar"], capture_output=True, text=True, timeout=10,
                               check=False)
        except (OSError, subprocess.SubprocessError):
            return ""
        return aviso_hw(r.stdout)

    @Slot(result=str)
    def logo(self):
        return _url(LOGO)

    @Slot(result=str)
    def cachorro(self):
        return _url(CACHORRO)

    @Slot(result=bool)
    def mostrarAoIniciar(self):  # noqa: N802
        return not ja_visto(self.estado)

    @Slot(bool)
    def definirMostrarAoIniciar(self, mostrar):  # noqa: N802
        if mostrar:
            (self.estado / MARCA).unlink(missing_ok=True)
        else:
            marcar_visto(self.estado)

    @Slot(result="QVariantMap")
    def sessao(self):
        """Sessão ao ligar e modo do Gaming (só com o xinguos-gaming instalado)."""
        if not shutil.which("xinguos-session-select"):
            return {"disponivel": False, "padrao": "ultima", "modo": "compativel"}
        try:
            r = subprocess.run(["xinguos-session-select", "--status"], capture_output=True, text=True,
                               timeout=10, check=False)
        except (OSError, subprocess.SubprocessError):
            return {"disponivel": False, "padrao": "ultima", "modo": "compativel"}
        valores = dict(linha.split("=", 1) for linha in r.stdout.splitlines() if "=" in linha)
        return {"disponivel": True, "padrao": valores.get("padrao", "ultima"),
                "modo": valores.get("modo", "compativel")}

    def _session_select(self, opcao, valor, validos, rotulo):
        if valor not in validos:
            return f"Valor inválido: {valor}"
        try:
            r = subprocess.run(["xinguos-session-select", opcao, valor], capture_output=True, text=True,
                               timeout=60, check=False)
        except (OSError, subprocess.SubprocessError) as e:
            return f"Não deu certo: {e}"
        if r.returncode != 0:
            return f"Não deu certo: {(r.stderr or '').strip() or r.returncode}"
        return f"{rotulo}: {valor}."

    @Slot(str, result=str)
    def definirPadrao(self, valor):  # noqa: N802
        return self._session_select("--default", valor, ("ultima", "desktop", "gaming"), "Ao ligar")

    @Slot(str, result=str)
    def definirModo(self, valor):  # noqa: N802
        return self._session_select("--modo", valor, ("compativel", "completo"), "Gaming Mode")

    @Slot("QVariantList", result=str)
    def instalar(self, ids):
        ids = [str(i) for i in ids]
        if not ids:
            return "Nada marcado."
        try:
            texto = roteiro(ids)
        except ValueError as e:
            return str(e)
        base = Path(os.environ.get("XDG_RUNTIME_DIR") or "/tmp")
        script = base / "xinguos-boasvindas.sh"
        script.write_text(texto, encoding="utf-8")
        script.chmod(0o700)
        try:
            subprocess.Popen(["konsole", "--hold", "-e", "bash", str(script)])
        except OSError as e:
            return f"Não consegui abrir o Konsole: {e}. O script está em {script}"
        return "Instalação aberta no Konsole."


def montar(estado: Path | None = None):
    app = QGuiApplication.instance() or QGuiApplication(sys.argv[:1])
    app.setApplicationName("Bem-vindo ao XInguOS")
    app.setDesktopFileName("org.xinguos.boasvindas")
    app.setWindowIcon(QIcon.fromTheme("xinguos"))
    backend = Backend(Path(estado or dir_estado()))
    engine = QQmlApplicationEngine()
    avisos: list[str] = []
    engine.warnings.connect(lambda lista: avisos.extend(w.toString() for w in lista))
    engine.rootContext().setContextProperty("boasvindas", backend)
    engine._backend = backend  # mantém vivo enquanto o engine existir
    engine.load(QUrl.fromLocalFile(str(QML)))
    return app, engine, avisos


def main(argv: list[str]) -> int:
    estado = dir_estado()
    if "--primeira-vez" in argv:
        if ja_visto(estado):
            return 0
        marcar_visto(estado)  # abre uma vez; a caixinha "Mostrar ao iniciar" religa
    app, engine, avisos = montar(estado)
    if not engine.rootObjects():
        for a in avisos:
            print(a, file=sys.stderr)
        return 1
    return app.exec()


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
