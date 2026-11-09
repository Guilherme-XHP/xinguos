// xinguos-foco (script do KWin): avisa o daemon xinguos-foco a cada janela ativada.
// O daemon registra o tempo de uso e dá prioridade de CPU/disco ao app em foco.
function avisarFoco(janela) {
    if (!janela || !janela.normalWindow) {
        return;
    }
    callDBus("org.xinguos.Foco", "/org/xinguos/Foco", "org.xinguos.Foco", "Foco",
             janela.desktopFileName || "", janela.resourceClass || "",
             janela.pid ? String(janela.pid) : "");
}

workspace.windowActivated.connect(avisarFoco);
