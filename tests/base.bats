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

@test "user@ delega io (e cpuset) para o xinguos-foco ajustar IOWeight" {
  grep -qx "Delegate=cpu cpuset io memory pids" "$B/90-xinguos-delegate.conf"
  grep -q 'user@.service.d/90-xinguos-delegate.conf' "$B/PKGBUILD"
}

# --- xinguos-teste: um comando que confere tudo e grava um log para mandar ---

TESTE=packages/xinguos/xinguos-base/xinguos-teste

@test "xinguos-teste: sistema vazio não quebra, aponta as falhas e grava o log" {
  T=$(mktemp -d); mkdir -p "$T/raiz" "$T/home"
  HOME="$T/home" XINGUOS_RAIZ="$T/raiz" run bash "$TESTE"
  echo "$output"
  [ "$status" -eq 1 ]
  grep -q 'FALHA.*tema escuro' <<<"$output"
  grep -q 'FALHA.*sessão XInguOS Gaming' <<<"$output"
  f=$(ls "$T/home"/xinguos-teste-*.txt)
  grep -q '== resumo' "$f"
  grep -q '== sessão Gaming' "$f"
  grep -q "$f" <<<"$output"
  rm -rf "$T"
}

@test "xinguos-teste: com tema, sessões e mídia protegida no lugar, dá OK" {
  T=$(mktemp -d); R="$T/raiz"; mkdir -p "$T/home"
  for f in /etc/os-release /usr/share/icons/Tela-XInguOS-dark/index.theme /usr/share/color-schemes/XInguOSEscuro.colors \
           /usr/share/plasma/desktoptheme/Materia-Color/metadata.desktop /usr/share/wayland-sessions/plasma.desktop \
           /usr/share/wayland-sessions/xinguos-gaming.desktop /usr/lib/xinguos/xinguos-gaming-sessao \
           /usr/share/polkit-1/rules.d/49-xinguos-sessao.rules /run/xinguos/midia-protegida; do
    mkdir -p "$R$(dirname "$f")"; echo x > "$R$f"
  done
  echo 'ID=xinguos' > "$R/etc/os-release"; mkdir -p "$R/run/archiso"
  HOME="$T/home" XINGUOS_RAIZ="$R" run bash "$TESTE"
  echo "$output"
  grep -q 'OK.*tema escuro' <<<"$output"
  grep -q 'OK.*sessão XInguOS Gaming' <<<"$output"
  grep -q 'OK.*XInguOS' <<<"$output"
  grep -q 'OK.*HD do Ventoy protegido' <<<"$output"
  grep -q 'install -Dm755 xinguos-teste "$pkgdir/usr/bin/xinguos-teste"' packages/xinguos/xinguos-base/PKGBUILD
  rm -rf "$T"
}

@test "xinguos-teste --gaming: abre o Gaming compatível numa janela e guarda o log" {
  T=$(mktemp -d); mkdir -p "$T/raiz" "$T/home" "$T/bin"
  printf '#!/usr/bin/env bash\necho "kwin_wayland $*" > "%s/chamada"\necho "steam: iniciando" >&2\nexit 0\n' "$T" > "$T/bin/kwin_wayland"
  chmod +x "$T/bin/kwin_wayland"
  HOME="$T/home" XINGUOS_RAIZ="$T/raiz" XINGUOS_ESPERA_GAMING=5 PATH="$T/bin:$PATH" run bash "$TESTE" --gaming
  echo "$output"
  [ "$status" -eq 0 ]
  grep -q -- '--xwayland' "$T/chamada"
  grep -q -- '--exit-with-session /usr/lib/xinguos/xinguos-steam-compativel' "$T/chamada"
  grep -q 'steam: iniciando' "$T/home/.local/state/xinguos/gaming-janela.log"
  # o log geral junta a janela de teste e a última sessão Gaming de verdade
  HOME="$T/home" XINGUOS_RAIZ="$T/raiz" run bash "$TESTE"
  f=$(ls "$T/home"/xinguos-teste-*.txt)
  grep -q 'gaming-janela.log' "$f"
  grep -q 'gaming-ultima-sessao.log' "$f"
  rm -rf "$T"
}

@test "xinguos-teste --gaming recusa rodar como root (o Steam é do usuário)" {
  grep -q 'rode sem sudo' "$TESTE"
}
