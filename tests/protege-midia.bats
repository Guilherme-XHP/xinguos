#!/usr/bin/env bats

P=iso/instalar/airootfs/usr/local/bin/xinguos-protege-midia

setup() {
  T=$(mktemp -d)
  export PATH="$PWD/tests/stubs-midia:$PATH" FAKE_LSBLK="$T/tabela" LOG="$T/log"
  export XINGUOS_PROTEGIDOS="$T/protegidos" XINGUOS_BOOTMNT=/run/archiso/bootmnt
  # PC do Xingu: SSD (sda, destino da instalação), HD USB do Ventoy (sdb, com backups),
  # e a ISO mapeada pelo Ventoy em /dev/mapper/ventoy por cima de sdb1
  cat > "$FAKE_LSBLK" <<'TAB'
/dev/sda disk - -
/dev/sda1 part EFI /dev/sda
/dev/sda2 part - /dev/sda
/dev/sdb disk - -
/dev/sdb1 part Ventoy /dev/sdb
/dev/sdb2 part VTOYEFI /dev/sdb
/dev/mapper/ventoy dm XINGUOS /dev/sdb1
TAB
  printf '#!/usr/bin/env bash\necho "%s"\n' "${FAKE_ORIGEM-/dev/mapper/ventoy}" > "$T/findmnt"
  printf '#!/usr/bin/env bash\necho "blockdev $*" >> "%s"\n' "$LOG" > "$T/blockdev"
  chmod +x "$T/findmnt" "$T/blockdev"
  export PATH="$T:$PATH"
  : > "$LOG"
}

teardown() { rm -rf "$T"; }

@test "Ventoy: o HD do Ventoy fica somente leitura e o SSD não" {
  run bash "$P"
  echo "$output"
  [ "$status" -eq 0 ]
  [ "$(cat "$XINGUOS_PROTEGIDOS")" = /dev/sdb ]
  grep -qx "blockdev --setro /dev/sdb" "$LOG"
  grep -qx "blockdev --setro /dev/sdb1" "$LOG"
  grep -qx "blockdev --setro /dev/sdb2" "$LOG"
  run grep -q "/dev/sda" "$LOG"
  [ "$status" -ne 0 ]
}

@test "pendrive comum (sem Ventoy): o disco de onde bootou é protegido pela origem do bootmnt" {
  cat > "$FAKE_LSBLK" <<'TAB'
/dev/sda disk - -
/dev/sda1 part - /dev/sda
/dev/sdc disk - -
/dev/sdc1 part XINGUOS /dev/sdc
TAB
  printf '#!/usr/bin/env bash\necho /dev/sdc1\n' > "$T/findmnt"
  run bash "$P"
  [ "$status" -eq 0 ]
  [ "$(cat "$XINGUOS_PROTEGIDOS")" = /dev/sdc ]
  grep -qx "blockdev --setro /dev/sdc1" "$LOG"
  run grep -q "/dev/sda" "$LOG"
  [ "$status" -ne 0 ]
}

@test "copytoram (bootmnt desmontado): o Ventoy ainda é achado pelo rótulo" {
  printf '#!/usr/bin/env bash\nexit 1\n' > "$T/findmnt"
  run bash "$P"
  [ "$status" -eq 0 ]
  [ "$(cat "$XINGUOS_PROTEGIDOS")" = /dev/sdb ]
}

@test "serviço roda antes do SDDM e o pós-instalação o remove" {
  S=iso/instalar/airootfs/etc/systemd/system/xinguos-protege-midia.service
  grep -qx "Before=display-manager.service" "$S"
  grep -qx "ExecStart=/usr/local/bin/xinguos-protege-midia" "$S"
  grep -q "xinguos-protege-midia.service" iso/instalar/airootfs/usr/lib/xinguos/instalador/pos-instalacao
}

@test "instalador só abre com o disco do Ventoy somente leitura" {
  I=iso/instalar/airootfs/usr/local/bin/xinguos-instalar
  printf '#!/usr/bin/env bash\necho "calamares $*" >> "%s"\n' "$LOG" > "$T/calamares"
  printf '#!/usr/bin/env bash\necho "protege" >> "%s"\n' "$LOG" > "$T/xinguos-protege-midia"
  printf '#!/usr/bin/env bash\necho "kdialog $*" >> "%s"\n' "$LOG" > "$T/kdialog"
  chmod +x "$T/calamares" "$T/xinguos-protege-midia" "$T/kdialog"
  # blockdev --getro: 0 = gravável
  printf '#!/usr/bin/env bash\necho "blockdev $*" >> "%s"\n[ "$1" = --getro ] && echo "${FAKE_RO:-1}"\nexit 0\n' "$LOG" > "$T/blockdev"
  FAKE_RO=0 run bash "$I"
  [ "$status" -ne 0 ]
  grep -q "^protege" "$LOG"
  grep -q "^kdialog --error" "$LOG"
  run grep -q "^calamares" "$LOG"
  [ "$status" -ne 0 ]
  : > "$LOG"
  FAKE_RO=1 run bash "$I"
  [ "$status" -eq 0 ]
  grep -q "^calamares" "$LOG"
}

@test "HD do Ventoy plugado ou resetado depois do boot também fica somente leitura (udev)" {
  R=iso/instalar/airootfs/etc/udev/rules.d/90-xinguos-protege-midia.rules
  grep -q 'ENV{ID_FS_LABEL}=="Ventoy|VTOYEFI"' "$R"
  grep -q 'RUN+="/usr/local/bin/xinguos-protege-midia"' "$R"
  grep -qx 'Exec=sudo -E /usr/local/bin/xinguos-instalar' iso/instalar/airootfs/usr/share/applications/instalar-xinguos.desktop
}
