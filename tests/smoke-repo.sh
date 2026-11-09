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
echo "smoke-repo: ok"
