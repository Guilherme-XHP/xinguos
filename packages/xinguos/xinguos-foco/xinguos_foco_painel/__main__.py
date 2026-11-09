"""xinguos-foco-painel: janela "Foco" (hoje, semana, prioridades e limites)."""
import subprocess
import sys
from datetime import date
from pathlib import Path

from PySide6.QtCore import QObject, QUrl, Slot
from PySide6.QtGui import QGuiApplication, QIcon
from PySide6.QtQml import QQmlApplicationEngine

from xinguos_foco.banco import Banco, caminho_padrao
from xinguos_foco.config import caminhos_padrao, carregar

from . import dados

QML = Path(__file__).resolve().with_name("Main.qml")
NOME = "org.xinguos.Foco"


def _executar(cmd: list[str]) -> int:
    try:
        return subprocess.run(cmd, stdin=subprocess.DEVNULL, capture_output=True, timeout=10, check=False).returncode
    except (OSError, subprocess.SubprocessError):
        return 127


class Backend(QObject):
    def __init__(self, banco: Banco, sistema: Path, usuario: Path):
        super().__init__()
        self.banco, self.sistema, self.usuario = banco, sistema, usuario

    def _cfg(self):
        return carregar(self.sistema, self.usuario)[0]

    @Slot(result="QVariantList")
    def hoje(self):
        return dados.resumo_hoje(self.banco, date.today())

    @Slot(result="QVariantList")
    def semana(self):
        return dados.resumo_semana(self.banco, date.today())

    @Slot(str, result="QVariantList")
    def dia(self, data_iso):
        return dados.resumo_dia(self.banco, data_iso)

    @Slot(result="QVariantList")
    def apps(self):
        return dados.apps_conhecidos(self.banco, self._cfg())

    @Slot(int, result=str)
    def texto(self, segundos):
        return dados.texto_tempo(segundos)

    @Slot("QVariantList", result=str)
    def salvar(self, mudancas):
        try:
            dados.aplicar_mudancas(self._cfg(), [dict(m) for m in mudancas], self.usuario, _executar)
        except OSError as e:
            return f"Não consegui salvar: {e}"
        # o daemon também relê sozinho em até 30 s se esta chamada falhar
        _executar(["busctl", "--user", "call", NOME, "/org/xinguos/Foco", NOME, "Recarregar"])
        return "Salvo."


def montar(db=None, sistema=None, usuario=None):
    app = QGuiApplication.instance() or QGuiApplication(sys.argv[:1])
    app.setApplicationName("Foco")
    app.setDesktopFileName("org.xinguos.foco")
    app.setWindowIcon(QIcon.fromTheme("preferences-system-time"))
    sis_padrao, usu_padrao = caminhos_padrao()
    backend = Backend(Banco(db or caminho_padrao()), Path(sistema or sis_padrao), Path(usuario or usu_padrao))
    engine = QQmlApplicationEngine()
    avisos: list[str] = []
    engine.warnings.connect(lambda lista: avisos.extend(w.toString() for w in lista))
    engine.rootContext().setContextProperty("foco", backend)
    engine._backend = backend  # mantém vivo enquanto o engine existir
    engine.load(QUrl.fromLocalFile(str(QML)))
    return app, engine, avisos


def main() -> int:
    app, engine, avisos = montar()
    if not engine.rootObjects():
        for a in avisos:
            print(a, file=sys.stderr)
        return 1
    return app.exec()


if __name__ == "__main__":
    sys.exit(main())
