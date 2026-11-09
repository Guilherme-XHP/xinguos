// XInguOS: layout inicial do Plasma (spec 6.1).
// Barra fina no topo, estilo Mac (launcher + menu global + bandeja + relógio)
// e dock flutuante centralizado embaixo, que some quando uma janela encosta.

// wallpaper do XInguOS em toda área de trabalho (pacote xinguos-branding)
var areas = desktops();
for (var i = 0; i < areas.length; i++) {
    areas[i].wallpaperPlugin = "org.kde.image";
    areas[i].currentConfigGroup = ["Wallpaper", "org.kde.image", "General"];
    areas[i].writeConfig("Image", "file:///usr/share/wallpapers/XInguOS");
}

var topo = new Panel;
topo.location = "top";
topo.height = 24;
topo.floating = false;
topo.lengthMode = "fill";
topo.hiding = "none";

var launcher = topo.addWidget("org.kde.plasma.kickoff");
launcher.currentConfigGroup = ["General"];
launcher.writeConfig("icon", "xinguos");

topo.addWidget("org.kde.plasma.appmenu");
topo.addWidget("org.kde.plasma.panelspacer");
topo.addWidget("org.kde.plasma.systemtray");
topo.addWidget("org.kde.plasma.digitalclock");

var dock = new Panel;
dock.location = "bottom";
dock.height = 52;
dock.floating = true;
dock.lengthMode = "fit";
dock.alignment = "center";
dock.hiding = "dodgewindows";

var tarefas = dock.addWidget("org.kde.plasma.icontasks");
tarefas.currentConfigGroup = ["General"];
tarefas.writeConfig("launchers", [
    "applications:org.kde.dolphin.desktop",
    "applications:firefox.desktop",
    "applications:org.kde.konsole.desktop",
    "applications:steam.desktop",
    "applications:systemsettings.desktop"
]);
