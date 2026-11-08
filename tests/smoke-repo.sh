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
pacman-key --init

# passo 1 do README: confiar na chave
curl -fsSL -o /tmp/xinguos.gpg "$url/xinguos.gpg"
pacman-key --add /tmp/xinguos.gpg
pacman-key --lsign-key "$fpr"

# passo 2: o bloco [xinguos]
printf '\n[xinguos]\nSigLevel = Required DatabaseOptional\nServer = %s\n' "$url" >> /etc/pacman.conf

# passo 3: o keyring
pacman -Sy --noconfirm xinguos-keyring
pacman -Q xinguos-keyring

# driver da GTX 10xx: baixa e verifica as assinaturas, sem instalar
pacman -Sw --noconfirm nvidia-580xx-utils nvidia-580xx-dkms lib32-nvidia-580xx-utils
echo "smoke-repo: ok"
