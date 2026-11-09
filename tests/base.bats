#!/usr/bin/env bats

B=packages/xinguos/xinguos-base

@test "regras de udev são válidas" {
  run udevadm verify "$B/60-xinguos-ioschedulers.rules"
  echo "$output"
  [ "$status" -eq 0 ]
}

@test "valores do spec 7.1" {
  grep -qx "zram-size = ram / 2" "$B/zram-generator.conf"
  grep -qx "compression-algorithm = zstd" "$B/zram-generator.conf"
  grep -qx "vm.swappiness = 180" "$B/90-xinguos.sysctl.conf"
  grep -qx "vm.page-cluster = 0" "$B/90-xinguos.sysctl.conf"
  grep -qx "SystemMaxUse=200M" "$B/90-xinguos-journald.conf"
  grep -qx 'NUMBER_LIMIT="10"' "$B/snapper-xinguos"
  grep -qx 'TIMELINE_CREATE="no"' "$B/snapper-xinguos"
  grep -qx "ManagedOOMMemoryPressure=kill" "$B/90-xinguos-oomd-user.conf"
  grep -qx "ManagedOOMSwap=kill" "$B/90-xinguos-oomd-root.conf"
  grep -q 'ATTR{queue/rotational}=="1", ATTR{queue/scheduler}="bfq"' "$B/60-xinguos-ioschedulers.rules"
  grep -q 'ATTR{queue/rotational}=="0", ATTR{queue/scheduler}="none"' "$B/60-xinguos-ioschedulers.rules"
}

@test "xinguos-base não depende de kernel nem de cups" {
  run bash -c "source $B/PKGBUILD; printf '%s\n' \"\${depends[@]}\""
  [ "$status" -eq 0 ]
  [[ "$output" == *zram-generator* ]]
  [[ "$output" == *xinguos-hwdetect* ]]
  run grep -xE 'linux-zen|linux-lts|linux|cups' <<<"$output"
  [ "$status" -ne 0 ]
}

@test "xinguos-kernels traz zen e lts com headers" {
  run bash -c "source packages/xinguos/xinguos-kernels/PKGBUILD; printf '%s\n' \"\${depends[@]}\""
  for k in linux-zen linux-zen-headers linux-lts linux-lts-headers; do
    grep -qx "$k" <<<"$output"
  done
}

@test "configs vão para diretórios de fornecedor" {
  [ -f "$B/PKGBUILD" ]
  run grep -E '"\$pkgdir/etc/' "$B/PKGBUILD"
  [ "$status" -ne 0 ]
}

@test ".install não falha sem rede" {
  export PATH="$BATS_TEST_DIRNAME/stubs:$PATH"
  export SYSTEMCTL_LOG="$BATS_TEST_TMPDIR/systemctl.log"
  run bash -c "source $B/xinguos-base.install; post_install"
  echo "$output"
  [ "$status" -eq 0 ]
  [[ "$output" == *"aviso: não consegui adicionar o Flathub"* ]]
  grep -q "enable systemd-oomd.service fstrim.timer NetworkManager.service bluetooth.service" "$SYSTEMCTL_LOG"
}

@test "atualizar não reabilita serviços" {
  export PATH="$BATS_TEST_DIRNAME/stubs:$PATH"
  export SYSTEMCTL_LOG="$BATS_TEST_TMPDIR/systemctl.log"
  run bash -c "source $B/xinguos-base.install; post_upgrade"
  [ "$status" -eq 0 ]
  [ ! -s "$SYSTEMCTL_LOG" ]
}
