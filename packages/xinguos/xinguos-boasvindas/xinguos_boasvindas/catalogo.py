"""O que o "Bem-vindo ao XInguOS" oferece instalar (spec 5.3 e 8.2)."""
from dataclasses import dataclass


@dataclass(frozen=True)
class Item:
    id: str
    nome: str
    descricao: str
    marcado: bool
    aviso: str = ""


ITENS: list[Item] = [
    Item("xinguos-apps", "Apps do XInguOS", "Firefox, Telegram, Kdenlive, OBS, GIMP, Blender, Godot, VS Code, "
         "LibreOffice e o resto da lista (vários GB, precisa de internet)", True),
    Item("vesktop", "Vesktop", "Discord mais leve (Flathub)", True),
    Item("zapzap", "ZapZap", "WhatsApp (Flathub)", True),
    Item("spotify", "Spotify", "Música (Flathub)", True),
    Item("natron", "Natron", "Composição de vídeo / VFX (Flathub)", True),
    Item("curseforge", "CurseForge", "Abre a página oficial para baixar o AppImage", True),
    Item("claude-code", "Claude Code", "Instalador oficial da Anthropic", True),
    Item("claude-desktop", "Claude Desktop", "Pacote da comunidade no AUR (claude-desktop)", False,
         aviso="não oficial: feito pela comunidade, pode quebrar"),
    Item("android-sdk", "Android SDK para o Godot", "cmdline-tools, platform-tools, build-tools, plataforma e NDK "
         "em ~/Android/Sdk (exportar pro Quest)", True),
    Item("proton-ge", "Proton-GE", "Versão mais nova do GE-Proton para o Steam", True),
    Item("protonup-qt", "ProtonUp-Qt", "Gerencia versões do Proton-GE e do Wine-GE (Flathub)", True),
    Item("impressao", "Impressão", "Instala e liga o CUPS", False),
]

POR_ID = {i.id: i for i in ITENS}
