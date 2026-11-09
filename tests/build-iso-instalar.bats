#!/usr/bin/env bats

setup_file() {
  export XINGUOS_REPO_URL=https://exemplo.invalid/repo
  PERFIL=$(XINGUOS_ISO_NOME=xinguos tools/build-iso.sh iso/instalar "$BATS_FILE_TMPDIR/out" --so-perfil | tail -1)
  export PERFIL
}

@test "nome e rótulo da ISO de instalação" {
  grep -q 'iso_name="xinguos"' "$PERFIL/profiledef.sh"
  grep -q 'iso_label="XINGUOS"' "$PERFIL/profiledef.sh"
}

@test "leva o instalador, os kernels do sistema instalado, branding e boas-vindas" {
  for p in xinguos-gaming calamares xinguos-kernels xinguos-branding xinguos-boasvindas xinguos-desktop grub efibootmgr os-prober btrfs-progs; do
    grep -qx "$p" "$PERFIL/packages.x86_64" || { echo "falta $p"; false; }
  done
  run grep -x xinguos-apps "$PERFIL/packages.x86_64"
  [ "$status" -ne 0 ]
}

@test "configuração do Calamares vai para /etc/calamares" {
  [ -f "$PERFIL/airootfs/etc/calamares/settings.conf" ]
  [ -f "$PERFIL/airootfs/etc/calamares/branding/xinguos/branding.desc" ]
  [ -f "$PERFIL/airootfs/etc/calamares/modules/shellprocess_pos.conf" ]
}

@test "sem protótipo do Marco 0 na ISO de instalação" {
  [ ! -e "$PERFIL/airootfs/usr/local/bin/steamos-session-select" ]
  [ ! -e "$PERFIL/airootfs/usr/local/bin/criar-persistencia" ]
  [ ! -e "$PERFIL/airootfs/etc/sudoers.d/xinguos-prototipo" ]
}

@test "live: usuário, proteção do disco, atalho do instalador e permissões" {
  [ -L "$PERFIL/airootfs/etc/systemd/system/multi-user.target.wants/xinguos-live-usuario.service" ]
  [ -L "$PERFIL/airootfs/etc/systemd/system/multi-user.target.wants/xinguos-protege-midia.service" ]
  grep -qF '["/usr/local/bin/xinguos-protege-midia"]="0:0:755"' "$PERFIL/profiledef.sh"
  grep -qF '["/usr/local/bin/xinguos-live-usuario"]="0:0:755"' "$PERFIL/profiledef.sh"
  grep -qF '["/usr/lib/xinguos/instalador/pos-instalacao"]="0:0:755"' "$PERFIL/profiledef.sh"
  grep -qF '["/etc/sudoers.d/10-xinguos-live"]="0:0:440"' "$PERFIL/profiledef.sh"
  grep -qF '["/etc/skel/Desktop/instalar-xinguos.desktop"]="0:0:755"' "$PERFIL/profiledef.sh"
  grep -qx 'User=live' "$PERFIL/airootfs/etc/sddm.conf.d/10-xinguos-live.conf"
  grep -qx 'Exec=sudo -E /usr/local/bin/xinguos-instalar' "$PERFIL/airootfs/usr/share/applications/instalar-xinguos.desktop"
}

@test "nome inválido é recusado" {
  run env XINGUOS_ISO_NOME='x; rm' tools/build-iso.sh iso/instalar "$BATS_TEST_TMPDIR/o" --so-perfil
  [ "$status" -ne 0 ]
}

@test "ISO de instalação usa squashfs (o unpackfs do Calamares copia dele); a de teste fica como está" {
  grep -q 'airootfs_image_type="squashfs"' "$PERFIL/profiledef.sh"
  grep -q 'source: "/run/xinguos/airootfs.sfs"' iso/instalar/calamares/modules/unpackfs.conf
}

@test "Bem-vindo não abre sozinho no live (instalar apps no live encheria a RAM)" {
  grep -q 'boasvindas-v1' "$PERFIL/airootfs/usr/local/bin/xinguos-live-usuario"
}
