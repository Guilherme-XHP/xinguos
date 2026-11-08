#!/usr/bin/env bash
# Prepara um container archlinux:latest para compilar e testar o XInguOS.
# Roda como root. Pode ser executado mais de uma vez.
set -euo pipefail

# habilita [multilib] (bloco vem comentado no pacman.conf padrão)
if ! grep -q '^\[multilib\]' /etc/pacman.conf; then
  sed -i '/^#\[multilib\]/,/^#Include/ s/^#//' /etc/pacman.conf
fi

pacman -Syu --noconfirm --needed base-devel git namcap bats shellcheck github-cli

# usuário sem privilégios para o makepkg (que se recusa a rodar como root)
if ! id builder >/dev/null 2>&1; then
  useradd -m builder
fi
echo 'builder ALL=(root) NOPASSWD: /usr/bin/pacman' > /etc/sudoers.d/builder
chmod 0440 /etc/sudoers.d/builder
