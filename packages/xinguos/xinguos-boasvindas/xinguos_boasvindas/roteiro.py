"""Gera o script bash que instala o que foi marcado. Ele roda num Konsole, para o usuário
ver o progresso e digitar a senha do sudo quando for preciso."""
from .catalogo import POR_ID

FLATHUB = ("flatpak remote-add --user --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo"
           " && flatpak install -y --user flathub {app}")

ANDROID_CMDLINE_TOOLS = "https://dl.google.com/android/repository/commandlinetools-linux-13114758_latest.zip"
ANDROID_PACOTES = ('"platform-tools" "build-tools;35.0.0" "platforms;android-35" '
                   '"ndk;28.1.13356709" "cmake;3.10.2.4988404"')

PASSOS: dict[str, str] = {
    "xinguos-apps": "sudo pacman -S --needed --noconfirm xinguos-apps",
    "vesktop": FLATHUB.format(app="dev.vencord.Vesktop"),
    "zapzap": FLATHUB.format(app="com.rtosta.zapzap"),
    "spotify": FLATHUB.format(app="com.spotify.Client"),
    "natron": FLATHUB.format(app="fr.natron.Natron"),
    "curseforge": "xdg-open https://www.curseforge.com/download/app",
    "claude-code": "curl -fsSL https://claude.ai/install.sh | bash",
    "claude-desktop": "paru -S --needed claude-desktop",
    "android-sdk": f"""sdk="$HOME/Android/Sdk"
  tmp=$(mktemp -d)
  mkdir -p "$sdk/cmdline-tools" &&
  curl -fL -o "$tmp/ct.zip" "{ANDROID_CMDLINE_TOOLS}" &&
  bsdtar -xf "$tmp/ct.zip" -C "$tmp" &&
  rm -rf "$sdk/cmdline-tools/latest" &&
  mv "$tmp/cmdline-tools" "$sdk/cmdline-tools/latest" &&
  {{ yes || true; }} | "$sdk/cmdline-tools/latest/bin/sdkmanager" --sdk_root="$sdk" --licenses >/dev/null &&
  "$sdk/cmdline-tools/latest/bin/sdkmanager" --sdk_root="$sdk" {ANDROID_PACOTES}
  r=$?; rm -rf "$tmp"; return $r""",
    "proton-ge": """d="$HOME/.local/share/Steam/compatibilitytools.d"
  mkdir -p "$d" &&
  url=$(curl -fsSL https://api.github.com/repos/GloriousEggroll/proton-ge-custom/releases/latest |
        python3 -c 'import json, sys; print(next(a["browser_download_url"] for a in json.load(sys.stdin)["assets"] if a["name"].endswith(".tar.gz")))') &&
  curl -fL "$url" | tar -xz -C "$d\"""",
    "protonup-qt": FLATHUB.format(app="net.davidotek.pupgui2"),
    "impressao": ("sudo pacman -S --needed --noconfirm cups cups-pdf print-manager system-config-printer"
                  " && sudo systemctl enable --now cups.socket"),
}

PASSOS_DE_USUARIO = ["vesktop", "zapzap", "spotify", "natron", "curseforge", "claude-code", "android-sdk",
                     "proton-ge", "protonup-qt"]

_CABECALHO = """#!/usr/bin/env bash
# Gerado pelo "Bem-vindo ao XInguOS". Cada passo roda mesmo que um anterior falhe.
set -uo pipefail
falhas=()
passo() {
  local nome=$1; shift
  echo
  echo "==> $nome"
  if "$@"; then echo "    ok"; else echo "    FALHOU: $nome"; falhas+=("$nome"); fi
}
"""

_RODAPE = """
echo
if [ ${#falhas[@]} -gt 0 ]; then
  printf 'Não deu certo: %s\\n' "$(IFS=', '; echo "${falhas[*]}")"
  echo "Dá para tentar de novo pelo Bem-vindo ao XInguOS, no menu de apps."
  exit 1
fi
echo "Tudo pronto!"
"""


def montar(passos: list[tuple[str, str]]) -> str:
    partes = [_CABECALHO]
    for n, (nome, comando) in enumerate(passos):
        nome_sh = nome.replace('"', "'")
        partes.append(f'passo_{n}() {{\n  {comando}\n}}\npasso "{nome_sh}" passo_{n}\n')
    partes.append(_RODAPE)
    return "".join(partes)


def roteiro(ids: list[str]) -> str:
    desconhecidos = [i for i in ids if i not in POR_ID or i not in PASSOS]
    if desconhecidos:
        raise ValueError(f"itens desconhecidos: {', '.join(desconhecidos)}")
    return montar([(POR_ID[i].nome, PASSOS[i]) for i in ids])
