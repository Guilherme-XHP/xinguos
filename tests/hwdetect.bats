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
