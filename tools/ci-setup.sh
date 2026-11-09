#!/usr/bin/env bash
# Prepara um container archlinux:latest para compilar e testar o XInguOS.
# Roda como root. Pode ser executado mais de uma vez.
set -euo pipefail

# habilita [multilib]
# (a imagem Docker pode não trazer o bloco: nesse caso ele é acrescentado)
if ! grep -q '^\[multilib\]' /etc/pacman.conf; then
  printf '\n[multilib]\nInclude = /etc/pacman.d/mirrorlist\n' >> /etc/pacman.conf
fi

pacman -Syu --noconfirm --needed base-devel git namcap bats shellcheck github-cli archiso nodejs python-pytest python-dbus-fast pyside6 desktop-file-utils

# usuário sem privilégios para o makepkg (que se recusa a rodar como root)
if ! id builder >/dev/null 2>&1; then
  useradd -m builder
fi
echo 'builder ALL=(root) NOPASSWD: /usr/bin/pacman' > /etc/sudoers.d/builder
chmod 0440 /etc/sudoers.d/builder
