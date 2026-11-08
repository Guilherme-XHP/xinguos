#!/usr/bin/env bats

setup_file() {
  export XINGUOS_REPO_URL=https://exemplo.invalid/repo
  PERFIL=$(tools/build-iso.sh iso/teste "$BATS_FILE_TMPDIR/out" --so-perfil | tail -1)
  export PERFIL
}

@test "perfil leva os pacotes do XInguOS" {
  grep -qx nvidia-580xx-dkms "$PERFIL/packages.x86_64"
  grep -qx gamescope-session-steam-git "$PERFIL/packages.x86_64"
  grep -qx plasma-desktop "$PERFIL/packages.x86_64"
}

@test "pacman.conf do perfil e do live têm [multilib] e [xinguos]" {
  for f in "$PERFIL/pacman.conf" "$PERFIL/airootfs/etc/pacman.conf"; do
    grep -q '^\[multilib\]' "$f"
    grep -q '^\[xinguos\]' "$f"
    grep -q '^Server = https://exemplo.invalid/repo' "$f"
  done
}

@test "protótipo e sudoers entram com permissões" {
  grep -qF '["/usr/local/bin/steamos-session-select"]="0:0:755"' "$PERFIL/profiledef.sh"
  grep -qF '["/usr/lib/os-session-select"]="0:0:755"' "$PERFIL/profiledef.sh"
  grep -qF '["/etc/sudoers.d/xinguos-prototipo"]="0:0:440"' "$PERFIL/profiledef.sh"
  grep -qF '["/etc/sudoers.d/10-xinguos-teste"]="0:0:440"' "$PERFIL/profiledef.sh"
  [ -f "$PERFIL/airootfs/usr/local/bin/steamos-session-select" ]
  [ -f "$PERFIL/airootfs/usr/lib/os-session-select" ]
  [ -f "$PERFIL/airootfs/usr/local/lib/xinguos/xinguos-escrever-sessao" ]
  [ -f "$PERFIL/airootfs/etc/sudoers.d/xinguos-prototipo" ]
  grep -q 'iso_name="xinguos-teste"' "$PERFIL/profiledef.sh"
}

@test "sddm e usuário habilitados" {
  [ "$(readlink "$PERFIL/airootfs/etc/systemd/system/display-manager.service")" = /usr/lib/systemd/system/sddm.service ]
  [ -L "$PERFIL/airootfs/etc/systemd/system/multi-user.target.wants/xinguos-teste-usuario.service" ]
  [ -L "$PERFIL/airootfs/etc/systemd/system/multi-user.target.wants/NetworkManager.service" ]
}

@test "boot com cow_spacesize" {
  run grep -rh 'archisobasedir=' "$PERFIL/grub" "$PERFIL/syslinux" "$PERFIL/efiboot/loader/entries"
  [ "$status" -eq 0 ]
  [ "${#lines[@]}" -gt 0 ]
  for l in "${lines[@]}"; do
    [[ "$l" == *cow_spacesize=8G* ]]
  done
}

@test "sem XINGUOS_REPO_URL falha" {
  run env XINGUOS_REPO_URL= tools/build-iso.sh iso/teste "$BATS_TEST_TMPDIR/o" --so-perfil
  [ "$status" -ne 0 ]
  [[ "$output" == *XINGUOS_REPO_URL* ]]
}
