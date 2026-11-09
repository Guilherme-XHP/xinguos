#!/usr/bin/env bats

POS=iso/instalar/airootfs/usr/lib/xinguos/instalador/pos-instalacao
CAL=iso/instalar/calamares

setup() {
  RAIZ=$(mktemp -d)
  export LOG="$RAIZ.log" PATH="$PWD/tests/stubs-instalador:$PATH" PERFIL=nvidia-580xx
  export INSTALADOS="calamares mkinitcpio-archiso linux linux-headers linux-zen linux-lts nvidia-580xx-dkms nvidia-580xx-utils lib32-nvidia-580xx-utils"
  : > "$LOG"
  for f in /etc/sddm.conf.d/10-xinguos-live.conf /etc/sudoers.d/10-xinguos-live \
           /etc/systemd/system/xinguos-live-usuario.service \
           /etc/systemd/system/multi-user.target.wants/xinguos-live-usuario.service \
           /etc/systemd/system/xinguos-protege-midia.service \
           /etc/systemd/system/multi-user.target.wants/xinguos-protege-midia.service \
           /usr/local/bin/xinguos-live-usuario /usr/local/bin/xinguos-protege-midia \
           /etc/skel/Desktop/instalar-xinguos.desktop /usr/share/applications/instalar-xinguos.desktop \
           /etc/mkinitcpio.conf.d/archiso.conf /etc/calamares/settings.conf \
           /usr/lib/xinguos/instalador/pos-instalacao; do
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
