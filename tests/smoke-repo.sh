#!/usr/bin/env bash
# Teste de fumaça do repositório publicado: num archlinux:latest LIMPO, segue
# exatamente o passo a passo do README e baixa o driver 580xx verificando as assinaturas.
#
# uso: smoke-repo.sh <url-do-servidor> <fingerprint>
set -euo pipefail

[ $# -eq 2 ] || { echo "uso: smoke-repo.sh <url-do-servidor> <fingerprint>" >&2; exit 2; }
url=$1
fpr=$2

if ! grep -q '^\[multilib\]' /etc/pacman.conf; then
  printf '\n[multilib]\nInclude = /etc/pacman.d/mirrorlist\n' >> /etc/pacman.conf
fi
# (só no CI) download de release do GitHub às vezes fica lento por uns segundos: sem o
# timeout, o pacman espera em vez de derrubar o teste
grep -q '^DisableDownloadTimeout' /etc/pacman.conf || sed -i '/^\[options\]/a DisableDownloadTimeout' /etc/pacman.conf
# passos 1 a 3 do README
bash "$(dirname "$0")/../tools/confiar-xinguos.sh" "$url" "$fpr"
pacman -Q xinguos-keyring

# driver da GTX 10xx: baixa e verifica as assinaturas, sem instalar
pacman -Sw --noconfirm nvidia-580xx-utils nvidia-580xx-dkms lib32-nvidia-580xx-utils
# xinguos-hwdetect instalado de verdade: o container não tem GPU conhecida
pacman -S --noconfirm xinguos-hwdetect
xinguos-hwdetect --detectar | tee /tmp/hwdetect.txt
grep -qx 'perfil=desconhecida' /tmp/hwdetect.txt
test -f /usr/share/libalpm/hooks/10-xinguos-nvidia-guard.hook

# toda a árvore de dependências da base resolve com repos oficiais + [xinguos], sem AUR
pacman -Sw --noconfirm xinguos-base xinguos-kernels
# desktop e apps: a árvore inteira resolve, puxa o Plasma e NUNCA o KDE Connect (spec 2.4)
pacman -Sp --print-format '%n' xinguos-desktop xinguos-apps > /tmp/arvore.txt
grep -qx plasma-desktop /tmp/arvore.txt
if grep -qx kdeconnect /tmp/arvore.txt; then echo "smoke-repo: xinguos-desktop/apps puxam kdeconnect" >&2; exit 1; fi
pacman -Sw --noconfirm xinguos-desktop
# foco: instala de verdade e o daemon responde no D-Bus (sem KWin, sem swayidle no container)
pacman -S --noconfirm xinguos-foco
# shellcheck disable=SC2016 # o script interno é expandido pelo sh de dentro do dbus-run-session
XINGUOS_FOCO_DB=/tmp/f.db XINGUOS_FOCO_CONFIG=/tmp/foco.toml dbus-run-session -- sh -c '
  xinguos-foco & d=$!
  for _ in $(seq 1 50); do busctl --user status org.xinguos.Foco >/dev/null 2>&1 && break; sleep 0.2; done
  busctl --user call org.xinguos.Foco /org/xinguos/Foco org.xinguos.Foco Foco sss firefox firefox 1
  busctl --user call org.xinguos.Foco /org/xinguos/Foco org.xinguos.Foco Totais
  r=$?; kill $d; wait $d; exit $r' | tee /tmp/foco.txt
grep -q '^s ' /tmp/foco.txt
# instalador: o pacote existe e traz os módulos em Python (unpackfs, bootloader...)
pacman -Sw --noconfirm calamares
pacman -Qlp /var/cache/pacman/pkg/calamares-*.pkg.tar.zst | grep -q '/unpackfs/main.py$'
pacman -Qlp /var/cache/pacman/pkg/calamares-*.pkg.tar.zst | grep -q '/bootloader/main.py$'
# Gaming Mode: o metapacote resolve tudo e o xinguos-gaming traz o gancho do Steam
pacman -Sp --print-format '%n' xinguos > /tmp/xinguos.txt
grep -qx xinguos-gaming /tmp/xinguos.txt
grep -qx steam /tmp/xinguos.txt
pacman -Sw --noconfirm xinguos-gaming
pacman -Qlp /var/cache/pacman/pkg/xinguos-gaming-*.pkg.tar.zst | grep -q '/usr/lib/os-session-select$'
echo "smoke-repo: ok"
