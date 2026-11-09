#!/usr/bin/env bats

HW=packages/xinguos/xinguos-hwdetect/xinguos-hwdetect

detectar() {
  XINGUOS_LSPCI_ARQUIVO="tests/fixtures/lspci/$1.txt" run "$HW" --detectar
  echo "$output"
  [ "$status" -eq 0 ]
}

@test "GTX 1060 → nvidia-580xx compatível" {
  detectar gtx1060
  [ "${lines[0]}" = "perfil=nvidia-580xx" ]
  [ "${lines[1]}" = "pacotes=nvidia-580xx-dkms nvidia-580xx-utils lib32-nvidia-580xx-utils" ]
  [ "${lines[2]}" = "gaming=compativel" ]
  [ "${lines[3]}" = "aviso=" ]
}

@test "RTX 2060 → nvidia-open completo" {
  detectar rtx2060
  [ "${lines[0]}" = "perfil=nvidia-open" ]
  [ "${lines[1]}" = "pacotes=nvidia-open-dkms nvidia-utils lib32-nvidia-utils" ]
  [ "${lines[2]}" = "gaming=completo" ]
}

@test "GTX 650 (Kepler) → nvidia-legada, sem pacotes, com aviso" {
  detectar gtx650
  [ "${lines[0]}" = "perfil=nvidia-legada" ]
  [ "${lines[1]}" = "pacotes=" ]
  [ "${lines[2]}" = "gaming=compativel" ]
  [[ "${lines[3]}" == "aviso=GPU NVIDIA antiga demais"* ]]
}

@test "RX 6600 → amd completo" {
  detectar rx6600
  [ "${lines[0]}" = "perfil=amd" ]
  [ "${lines[1]}" = "pacotes=mesa lib32-mesa vulkan-radeon lib32-vulkan-radeon" ]
  [ "${lines[2]}" = "gaming=completo" ]
}

@test "UHD 630 → intel completo" {
  detectar uhd630
  [ "${lines[0]}" = "perfil=intel" ]
  [ "${lines[1]}" = "pacotes=mesa lib32-mesa vulkan-intel lib32-vulkan-intel" ]
  [ "${lines[2]}" = "gaming=completo" ]
}

@test "duas GPUs → varias, sem pacotes, aviso ensina --forcar" {
  detectar notebook
  [ "${lines[0]}" = "perfil=varias" ]
  [ "${lines[1]}" = "pacotes=" ]
  [ "${lines[2]}" = "gaming=compativel" ]
  [[ "${lines[3]}" == *"--forcar"* ]]
}

@test "sem GPU → desconhecida" {
  detectar sem-gpu
  [ "${lines[0]}" = "perfil=desconhecida" ]
  [ "${lines[1]}" = "pacotes=" ]
  [ "${lines[3]}" = "aviso=nenhuma GPU reconhecida; nada foi instalado" ]
}

@test "saída tem sempre 4 linhas" {
  for f in tests/fixtures/lspci/*.txt; do
    XINGUOS_LSPCI_ARQUIVO="$f" run "$HW" --detectar
    [ "$status" -eq 0 ]
    [ "$(printf '%s\n' "$output" | wc -l)" -eq 4 ]
  done
}

preparar_apply() {
  export PATH="$BATS_TEST_DIRNAME/stubs:$PATH"
  export PACMAN_LOG="$BATS_TEST_TMPDIR/pacman.log"
  : > "$PACMAN_LOG"
  export XINGUOS_ETC="$BATS_TEST_TMPDIR/etc-xinguos"
  export XINGUOS_MODPROBE_DIR="$BATS_TEST_TMPDIR/modprobe.d"
}

@test "--apply instala os pacotes do perfil e grava modprobe e gaming.conf" {
  preparar_apply
  XINGUOS_LSPCI_ARQUIVO=tests/fixtures/lspci/gtx1060.txt run "$HW" --apply
  echo "$output"
  [ "$status" -eq 0 ]
  grep -qx -- "-S --needed nvidia-580xx-dkms nvidia-580xx-utils lib32-nvidia-580xx-utils" "$PACMAN_LOG"
  grep -qx "options nvidia_drm modeset=1" "$XINGUOS_MODPROBE_DIR/xinguos-nvidia.conf"
  grep -qx "MODO_GAMING=compativel" "$XINGUOS_ETC/gaming.conf"
}

@test "--apply não sobrescreve gaming.conf existente" {
  preparar_apply
  mkdir -p "$XINGUOS_ETC"
  echo "MODO_GAMING=completo" > "$XINGUOS_ETC/gaming.conf"
  XINGUOS_LSPCI_ARQUIVO=tests/fixtures/lspci/gtx1060.txt run "$HW" --apply
  [ "$status" -eq 0 ]
  grep -qx "MODO_GAMING=completo" "$XINGUOS_ETC/gaming.conf"
}

@test "pacman falhou → nada é escrito" {
  preparar_apply
  PACMAN_STATUS=1 XINGUOS_LSPCI_ARQUIVO=tests/fixtures/lspci/gtx1060.txt run "$HW" --apply
  [ "$status" -ne 0 ]
  grep -q -- "-S --needed nvidia-580xx-dkms" "$PACMAN_LOG"
  [ ! -e "$XINGUOS_MODPROBE_DIR/xinguos-nvidia.conf" ]
  [ ! -e "$XINGUOS_ETC/gaming.conf" ]
}

@test "--forcar escolhe o perfil mesmo com duas GPUs" {
  preparar_apply
  XINGUOS_LSPCI_ARQUIVO=tests/fixtures/lspci/notebook.txt run "$HW" --apply --forcar nvidia-580xx
  echo "$output"
  [ "$status" -eq 0 ]
  grep -qx -- "-S --needed nvidia-580xx-dkms nvidia-580xx-utils lib32-nvidia-580xx-utils" "$PACMAN_LOG"
}

@test "--forcar com perfil inválido sai 2" {
  preparar_apply
  XINGUOS_LSPCI_ARQUIVO=tests/fixtures/lspci/gtx1060.txt run "$HW" --apply --forcar inventado
  [ "$status" -eq 2 ]
  [[ "$output" == *"perfil inválido: inventado"* ]]
  run grep -- "-S" "$PACMAN_LOG"
  [ "$status" -ne 0 ]
}

@test "--hook avisa quando falta driver e não chama pacman -S" {
  preparar_apply
  PACMAN_Q_STATUS=1 XINGUOS_LSPCI_ARQUIVO=tests/fixtures/lspci/gtx1060.txt run "$HW" --hook
  echo "$output"
  [ "$status" -eq 0 ]
  [[ "$output" == *"rode: sudo xinguos-hwdetect --apply"* ]]
  run grep -- "-S" "$PACMAN_LOG"
  [ "$status" -ne 0 ]
}

@test "--hook não sobrescreve gaming.conf" {
  preparar_apply
  mkdir -p "$XINGUOS_ETC"
  echo "MODO_GAMING=completo" > "$XINGUOS_ETC/gaming.conf"
  XINGUOS_LSPCI_ARQUIVO=tests/fixtures/lspci/gtx1060.txt run "$HW" --hook
  [ "$status" -eq 0 ]
  grep -qx "MODO_GAMING=completo" "$XINGUOS_ETC/gaming.conf"
}

@test "--guard bloqueia GTX 1060" {
  XINGUOS_LSPCI_ARQUIVO=tests/fixtures/lspci/gtx1060.txt run "$HW" --guard
  echo "$output"
  [ "$status" -eq 1 ]
  [[ "$output" == *"só funciona com o driver 580xx"* ]]
}

@test "--guard libera RTX, AMD e várias GPUs" {
  for f in rtx2060 rx6600 notebook; do
    XINGUOS_LSPCI_ARQUIVO="tests/fixtures/lspci/$f.txt" run "$HW" --guard
    [ "$status" -eq 0 ]
  done
}

@test "hook do guard é PreTransaction com AbortOnFail e cobre nvidia-open-dkms e nvidia-utils" {
  local h=packages/xinguos/xinguos-hwdetect/10-xinguos-nvidia-guard.hook
  grep -qx "When = PreTransaction" "$h"
  grep -qx "AbortOnFail" "$h"
  grep -qx "Exec = /usr/bin/xinguos-hwdetect --guard" "$h"
  for t in nvidia nvidia-dkms nvidia-lts nvidia-open nvidia-open-dkms nvidia-open-lts nvidia-utils; do
    grep -qx "Target = $t" "$h"
  done
  grep -qx "Operation = Install" "$h"
  grep -qx "Operation = Upgrade" "$h"
}

@test "hook do hwdetect roda --hook só para o próprio pacote" {
  local h=packages/xinguos/xinguos-hwdetect/90-xinguos-hwdetect.hook
  grep -qx "Target = xinguos-hwdetect" "$h"
  [ "$(grep -c '^Target' "$h")" -eq 1 ]
  grep -qx "When = PostTransaction" "$h"
  grep -qx "Exec = /usr/bin/xinguos-hwdetect --hook" "$h"
}
