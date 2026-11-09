#!/usr/bin/env bats

B=packages/xinguos/xinguos-boasvindas

@test "wrapper, atalhos e autostart do Bem-vindo" {
  grep -qx 'exec env PYTHONPATH=/usr/lib/xinguos/boasvindas python3 -m xinguos_boasvindas "$@"' "$B/xinguos-boasvindas"
  desktop-file-validate "$B/org.xinguos.boasvindas.desktop"
  desktop-file-validate "$B/xinguos-boasvindas-autostart.desktop"
  grep -qx 'Exec=xinguos-boasvindas --primeira-vez' "$B/xinguos-boasvindas-autostart.desktop"
}

@test "pacote instala nos caminhos certos e o desktop puxa o Bem-vindo" {
  for p in /usr/lib/xinguos/boasvindas/xinguos_boasvindas /usr/bin/xinguos-boasvindas \
           /usr/share/applications/org.xinguos.boasvindas.desktop /etc/xdg/autostart/xinguos-boasvindas.desktop; do
    grep -q "$p" "$B/PKGBUILD"
  done
  run bash -c "source packages/xinguos/xinguos-desktop/PKGBUILD; printf '%s\n' \"\${depends[@]}\""
  grep -qx xinguos-boasvindas <<<"$output"
  b=$(grep -nx 'xinguos/xinguos-boasvindas' packages/ordem.txt | cut -d: -f1)
  d=$(grep -nx 'xinguos/xinguos-desktop' packages/ordem.txt | cut -d: -f1)
  [ -n "$b" ] && [ "$b" -lt "$d" ]
}
