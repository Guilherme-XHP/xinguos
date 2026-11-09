#!/usr/bin/env bash
# Teste de instalação do XInguOS sem interface (CI): faz o que o Calamares faz com o
# sistema copiado — extrai o airootfs.sfs da ISO, roda o pos-instalacao no chroot — e
# confere que virou um sistema instalado de verdade (kernels + initramfs, nada do live).
#
# uso: teste-instalacao.sh <xinguos.iso> <dir-de-trabalho>   (root, container --privileged)
set -euo pipefail

[ $# -eq 2 ] || { echo "uso: teste-instalacao.sh <iso> <dir-de-trabalho>" >&2; exit 2; }
iso=$1
trab=$2
falhou() { echo "teste-instalacao: FALHOU: $*" >&2; exit 1; }

mkdir -p "$trab/iso" "$trab/alvo"
mount -o loop,ro "$iso" "$trab/iso"
trap 'umount -R "$trab/alvo" 2>/dev/null || true; umount "$trab/iso" 2>/dev/null || true' EXIT
unsquashfs -f -q -d "$trab/alvo" "$trab/iso/arch/x86_64/airootfs.sfs"

alvo=$trab/alvo
# o que o live cria no boot (o usuário live), para o pós-instalação ter o que remover
arch-chroot "$alvo" useradd -m -G wheel live
[ -x "$alvo/usr/lib/xinguos/instalador/pos-instalacao" ] || falhou "pos-instalacao não está na ISO (ou sem +x)"
[ -f "$alvo/etc/calamares/settings.conf" ] || falhou "configuração do Calamares não está na ISO"
[ -f "$alvo/etc/systemd/system/multi-user.target.wants/xinguos-protege-midia.service" ] || falhou "proteção do disco não está habilitada no live"

echo "==> rodando o pos-instalacao no chroot"
arch-chroot "$alvo" /usr/lib/xinguos/instalador/pos-instalacao

echo "==> conferindo"
for k in linux-zen linux-lts; do
  [ -s "$alvo/boot/vmlinuz-$k" ] || falhou "sem /boot/vmlinuz-$k"
  [ -s "$alvo/boot/initramfs-$k.img" ] || falhou "sem /boot/initramfs-$k.img"
  grep -q "$k" "$alvo/etc/mkinitcpio.d/$k.preset" || falhou "preset de $k"
done
[ ! -e "$alvo/etc/mkinitcpio.conf.d/archiso.conf" ] || falhou "sobrou a config do archiso no mkinitcpio"
for f in /etc/calamares /etc/sddm.conf.d/10-xinguos-live.conf /etc/sudoers.d/10-xinguos-live \
         /etc/systemd/system/multi-user.target.wants/xinguos-protege-midia.service \
         /usr/lib/xinguos/instalador /etc/skel/Desktop/instalar-xinguos.desktop; do
  [ ! -e "$alvo$f" ] || falhou "sobrou do live: $f"
done
! arch-chroot "$alvo" id live >/dev/null 2>&1 || falhou "usuário live continua no sistema"
! arch-chroot "$alvo" pacman -Q calamares >/dev/null 2>&1 || falhou "calamares continua instalado"
! arch-chroot "$alvo" pacman -Q linux >/dev/null 2>&1 || falhou "kernel do live (linux) continua instalado"
arch-chroot "$alvo" passwd -S root | grep -q ' L ' || falhou "root não ficou travado"
grep -qx 'SNAPPER_CONFIGS="root"' "$alvo/etc/conf.d/snapper" || falhou "snapper não configurado"
grep -qx 'ID=xinguos' "$alvo/etc/os-release" || falhou "os-release não é do XInguOS"
arch-chroot "$alvo" pacman -Q xinguos-desktop xinguos-boasvindas xinguos-foco xinguos-branding >/dev/null \
  || falhou "faltam pacotes do XInguOS no sistema instalado"
echo "teste-instalacao: ok"
