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
