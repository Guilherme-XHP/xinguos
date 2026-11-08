#!/usr/bin/env bash
# Passos 1 a 3 do README: confiar na chave do XInguOS, adicionar o [xinguos] e instalar o keyring.
# Roda como root num Arch (usado pelo smoke e pelo job da ISO).
#
# uso: confiar-xinguos.sh <url-do-servidor> <fingerprint>
set -euo pipefail

[ $# -eq 2 ] || { echo "uso: confiar-xinguos.sh <url-do-servidor> <fingerprint>" >&2; exit 2; }
url=$1
fpr=$2

pacman-key --init
curl -fsSL -o /tmp/xinguos.gpg "$url/xinguos.gpg"
pacman-key --add /tmp/xinguos.gpg
pacman-key --lsign-key "$fpr"

if ! grep -q '^\[xinguos\]' /etc/pacman.conf; then
  printf '\n[xinguos]\nSigLevel = Required DatabaseOptional\nServer = %s\n' "$url" >> /etc/pacman.conf
fi
pacman -Sy --noconfirm xinguos-keyring
