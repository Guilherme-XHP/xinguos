#!/usr/bin/env bats

POS=iso/instalar/airootfs/usr/lib/xinguos/instalador/pos-instalacao
CAL=iso/instalar/calamares

setup() {
  RAIZ=$(mktemp -d)
  export LOG="$RAIZ.log" PATH="$PWD/tests/stubs-instalador:$PATH" PERFIL=nvidia-580xx
  export INSTALADOS="cloud-init open-vm-tools calamares mkinitcpio-archiso linux linux-headers linux-zen linux-lts nvidia-580xx-dkms nvidia-580xx-utils lib32-nvidia-580xx-utils"
  : > "$LOG"
  for f in /etc/sddm.conf.d/10-xinguos-live.conf /etc/sudoers.d/10-xinguos-live \
           /etc/systemd/system/xinguos-live-usuario.service \
           /etc/systemd/system/multi-user.target.wants/xinguos-live-usuario.service \
           /etc/systemd/system/xinguos-protege-midia.service \
           /etc/systemd/system/multi-user.target.wants/xinguos-protege-midia.service \
           /etc/systemd/system/xinguos-live-chaveiro.service \
           /etc/systemd/system/multi-user.target.wants/xinguos-live-chaveiro.service \
           /usr/local/bin/xinguos-live-usuario /usr/local/bin/xinguos-protege-midia \
           /etc/skel/Desktop/instalar-xinguos.desktop /usr/share/applications/instalar-xinguos.desktop \
           /etc/mkinitcpio.conf.d/archiso.conf /etc/calamares/settings.conf \
           /usr/lib/xinguos/instalador/pos-instalacao \
           /etc/ssh/sshd_config.d/10-archiso.conf /etc/systemd/network/20-ethernet.network \
           /etc/systemd/networkd.conf.d/ipv6-privacy-extensions.conf /etc/systemd/resolved.conf.d/archiso.conf \
           /etc/systemd/system/multi-user.target.wants/sshd.service \
           /etc/systemd/system/multi-user.target.wants/systemd-networkd.service \
           /etc/systemd/system/multi-user.target.wants/systemd-resolved.service \
           /etc/systemd/system/multi-user.target.wants/vboxservice.service \
           /etc/systemd/system/sockets.target.wants/systemd-networkd.socket \
           /etc/systemd/system/network-online.target.wants/systemd-networkd-wait-online.service \
           /etc/systemd/system/cloud-init.target.wants/cloud-init-main.service \
           /etc/udev/rules.d/90-xinguos-protege-midia.rules /usr/local/bin/xinguos-instalar; do
    mkdir -p "$RAIZ$(dirname "$f")"; echo x > "$RAIZ$f"
  done
  printf 'root:x:0:0::/root:/bin/bash\nlive:x:1000:1000::/home/live:/bin/bash\n' > "$RAIZ/etc/passwd"
  for k in 7.2.14-zen1-1-zen:linux-zen 6.12.60-1-lts:linux-lts; do
    mkdir -p "$RAIZ/usr/lib/modules/${k%%:*}"
    echo "${k#*:}" > "$RAIZ/usr/lib/modules/${k%%:*}/pkgbase"
    echo "kernel ${k#*:}" > "$RAIZ/usr/lib/modules/${k%%:*}/vmlinuz"
  done
  mkdir -p "$RAIZ/usr/share/mkinitcpio" "$RAIZ/usr/share/snapper/config-templates" "$RAIZ/etc/conf.d" "$RAIZ/boot"
  printf 'ALL_kver="/boot/vmlinuz-%%PKGBASE%%"\ndefault_image="/boot/initramfs-%%PKGBASE%%.img"\n' > "$RAIZ/usr/share/mkinitcpio/hook.preset"
  printf 'SUBVOLUME="/"\nNUMBER_LIMIT="10"\n' > "$RAIZ/usr/share/snapper/config-templates/xinguos"
  echo 'SNAPPER_CONFIGS=""' > "$RAIZ/etc/conf.d/snapper"
}

teardown() { rm -rf "$RAIZ" "$LOG"; }

@test "tira tudo que é só do live e trava o root" {
  run bash "$POS" --raiz "$RAIZ"
  echo "$output"
  [ "$status" -eq 0 ]
  for f in /etc/sddm.conf.d/10-xinguos-live.conf /etc/sudoers.d/10-xinguos-live \
           /etc/systemd/system/xinguos-live-usuario.service /etc/systemd/system/xinguos-protege-midia.service \
           /etc/systemd/system/xinguos-live-chaveiro.service \
           /etc/systemd/system/multi-user.target.wants/xinguos-live-chaveiro.service \
           /usr/local/bin/xinguos-protege-midia /etc/skel/Desktop/instalar-xinguos.desktop \
           /etc/mkinitcpio.conf.d/archiso.conf /etc/calamares /usr/lib/xinguos/instalador; do
    [ ! -e "$RAIZ$f" ] || { echo "sobrou $f"; false; }
  done
  grep -qx "userdel -r live" "$LOG"
  grep -qx "passwd -l root" "$LOG"
  grep -qx "pacman -Rns --noconfirm calamares mkinitcpio-archiso linux linux-headers" "$LOG"
}

@test "presets e vmlinuz do zen e do lts, e initramfs gerado" {
  run bash "$POS" --raiz "$RAIZ"
  [ "$status" -eq 0 ]
  grep -qx 'default_image="/boot/initramfs-linux-zen.img"' "$RAIZ/etc/mkinitcpio.d/linux-zen.preset"
  grep -qx 'ALL_kver="/boot/vmlinuz-linux-lts"' "$RAIZ/etc/mkinitcpio.d/linux-lts.preset"
  grep -qx "kernel linux-zen" "$RAIZ/boot/vmlinuz-linux-zen"
  grep -qx "kernel linux-lts" "$RAIZ/boot/vmlinuz-linux-lts"
  grep -qx "mkinitcpio -P" "$LOG"
}

@test "GTX 10xx (580xx): mantém o driver e liga o modeset" {
  run bash "$POS" --raiz "$RAIZ"
  [ "$status" -eq 0 ]
  run grep -q -- "-Rdd" "$LOG"
  [ "$status" -ne 0 ]
  grep -qx "options nvidia_drm modeset=1" "$RAIZ/etc/modprobe.d/xinguos-nvidia.conf"
}

@test "AMD: tira o 580xx e instala o driver certo pelo hwdetect" {
  PERFIL=amd run bash "$POS" --raiz "$RAIZ"
  [ "$status" -eq 0 ]
  grep -qx "pacman -Rdd --noconfirm nvidia-580xx-dkms nvidia-580xx-utils lib32-nvidia-580xx-utils" "$LOG"
  grep -qx "xinguos-hwdetect --apply" "$LOG"
}

@test "sem internet o driver fica para depois, sem falhar a instalação" {
  PERFIL=intel PACMAN_SY_STATUS=1 run bash "$POS" --raiz "$RAIZ"
  [ "$status" -eq 0 ]
  [[ "$output" == *"sudo xinguos-hwdetect --apply"* ]]
  run grep -qx "xinguos-hwdetect --apply" "$LOG"
  [ "$status" -ne 0 ]
}

@test "snapper configurado para / e falha do mkinitcpio derruba (essencial)" {
  run bash "$POS" --raiz "$RAIZ"
  [ "$status" -eq 0 ]
  grep -qx 'SNAPPER_CONFIGS="root"' "$RAIZ/etc/conf.d/snapper"
  grep -qx 'NUMBER_LIMIT="10"' "$RAIZ/etc/snapper/configs/root"
  MKINITCPIO_STATUS=1 run bash "$POS" --raiz "$RAIZ"
  [ "$status" -ne 0 ]
}

@test "sem kernel nenhum é erro; rodar duas vezes não quebra" {
  run bash "$POS" --raiz "$RAIZ"
  [ "$status" -eq 0 ]
  run bash "$POS" --raiz "$RAIZ"
  [ "$status" -eq 0 ]
  rm -rf "$RAIZ/usr/lib/modules"
  run bash "$POS" --raiz "$RAIZ"
  [ "$status" -ne 0 ]
}

@test "configuração do Calamares: YAML válido e sequência certa" {
  for f in "$CAL/settings.conf" "$CAL"/modules/*.conf "$CAL/branding/xinguos/branding.desc"; do
    python3 -c 'import sys, yaml; yaml.safe_load(open(sys.argv[1]))' "$f" || { echo "YAML inválido: $f"; false; }
  done
  python3 tests/conferir-calamares.py "$CAL"
}

@test "sobras do perfil baseline do archiso saem (sshd aberto, networkd, cloud-init, convidado de VM)" {
  run bash "$POS" --raiz "$RAIZ"
  [ "$status" -eq 0 ]
  for f in /etc/ssh/sshd_config.d/10-archiso.conf /etc/systemd/network/20-ethernet.network \
           /etc/systemd/system/multi-user.target.wants/sshd.service \
           /etc/systemd/system/multi-user.target.wants/systemd-networkd.service \
           /etc/systemd/system/multi-user.target.wants/vboxservice.service \
           /etc/systemd/system/sockets.target.wants/systemd-networkd.socket \
           /etc/systemd/system/network-online.target.wants/systemd-networkd-wait-online.service \
           /etc/systemd/system/cloud-init.target.wants /etc/udev/rules.d/90-xinguos-protege-midia.rules \
           /usr/local/bin/xinguos-instalar; do
    [ ! -e "$RAIZ$f" ] || { echo "sobrou $f"; false; }
  done
  # o resolved fica (o NetworkManager usa); só a config do archiso sai
  [ -e "$RAIZ/etc/systemd/system/multi-user.target.wants/systemd-resolved.service" ]
  [ ! -e "$RAIZ/etc/systemd/resolved.conf.d/archiso.conf" ]
  grep -q "^pacman -Rns --noconfirm cloud-init open-vm-tools" "$LOG"
}

@test "chaveiro do pacman é criado no sistema instalado (senão nenhum pacman -S funciona)" {
  run bash "$POS" --raiz "$RAIZ"
  [ "$status" -eq 0 ]
  grep -qx "pacman-key --init" "$LOG"
  grep -qx "pacman-key --populate archlinux xinguos" "$LOG"
  grep -qx "gpgconf --homedir /etc/pacman.d/gnupg --kill all" "$LOG"
  # antes de qualquer pacman -Sy (driver de GPU que não seja a 580xx)
  : > "$LOG"
  PERFIL=amd run bash "$POS" --raiz "$RAIZ"
  [ "$(grep -n 'pacman-key --populate' "$LOG" | cut -d: -f1)" -lt "$(grep -n '^pacman -Sy' "$LOG" | cut -d: -f1)" ]
}

@test "live: chaveiro do pacman criado no boot (pacman -S funciona no live)" {
  local s=iso/instalar/airootfs/etc/systemd/system/xinguos-live-chaveiro.service
  grep -qx 'ExecStart=/usr/bin/pacman-key --init' "$s"
  grep -qx 'ExecStart=/usr/bin/pacman-key --populate archlinux xinguos' "$s"
  grep -qx 'WantedBy=multi-user.target' "$s"
  grep -qx 'Before=archlinux-keyring-wkd-sync.service' "$s" || grep -qx 'Type=oneshot' "$s"
  cmp -s "$s" iso/teste/airootfs/etc/systemd/system/xinguos-live-chaveiro.service
}

@test "GRUB: padrões valem mesmo com /etc/default/grub do pacote, os-prober ligado e tema XInguOS" {
  python3 - "$CAL/modules/grubcfg.conf" <<'PY'
import sys, yaml
g = yaml.safe_load(open(sys.argv[1], encoding="utf-8"))
assert g["always_use_defaults"] is True, "senão o Calamares ignora os defaults (o grub do Arch já traz /etc/default/grub)"
assert g["keep_distributor"] is False and "keepDistributor" not in g
d = g["defaults"]
assert d["GRUB_DISABLE_OS_PROBER"] is False
assert d["GRUB_THEME"] == "/usr/share/grub/themes/xinguos/theme.txt"
assert d["GRUB_TERMINAL_OUTPUT"] == "gfxterm"
# Btrfs: o GRUB não grava o grubenv, então "saved" não funciona
assert str(d["GRUB_DEFAULT"]) == "0" and "GRUB_SAVEDEFAULT" not in d
assert "splash" in g["kernel_params"] and "quiet" in g["kernel_params"]
PY
}

@test "boot com a logo: plymouth no initramfs (depois do systemd/udev) e tema xinguos" {
  printf 'MODULES=()\nHOOKS=(base systemd autodetect microcode modconf kms keyboard sd-vconsole block filesystems fsck)\n' > "$RAIZ/etc/mkinitcpio.conf"
  run bash "$POS" --raiz "$RAIZ"
  echo "$output"
  [ "$status" -eq 0 ]
  grep -qx 'HOOKS=(base systemd plymouth autodetect microcode modconf kms keyboard sd-vconsole block filesystems fsck)' "$RAIZ/etc/mkinitcpio.conf"
  grep -qx 'plymouth-set-default-theme xinguos' "$LOG"
  # tema antes do initramfs (o hook copia o tema para dentro dele)
  [ "$(grep -n 'plymouth-set-default-theme' "$LOG" | cut -d: -f1)" -lt "$(grep -n '^mkinitcpio -P' "$LOG" | cut -d: -f1)" ]
  # rodar de novo não duplica; HOOKS com udev também serve
  run bash "$POS" --raiz "$RAIZ"
  [ "$(grep -o plymouth "$RAIZ/etc/mkinitcpio.conf" | wc -l)" -eq 1 ]
  printf 'HOOKS=(base udev autodetect modconf block filesystems fsck)\n' > "$RAIZ/etc/mkinitcpio.conf"
  run bash "$POS" --raiz "$RAIZ"
  grep -qx 'HOOKS=(base udev plymouth autodetect modconf block filesystems fsck)' "$RAIZ/etc/mkinitcpio.conf"
}
