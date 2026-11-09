#!/usr/bin/env bats

F=packages/xinguos/xinguos-foco

@test "unidade do usuário é válida" {
  # cópia com ExecStart que existe no CI (o pacote não está instalado aqui)
  local d; d=$(mktemp -d)
  sed 's#^ExecStart=.*#ExecStart=/usr/bin/true#' "$F/xinguos-foco.service" > "$d/xinguos-foco.service"
  run env XDG_RUNTIME_DIR="$d" systemd-analyze --user verify "$d/xinguos-foco.service"
  echo "$output"
  [ "$status" -eq 0 ]
  grep -qx "ExecStart=/usr/bin/xinguos-foco" "$F/xinguos-foco.service"
  grep -qx "PartOf=graphical-session.target" "$F/xinguos-foco.service"
  grep -qx "WantedBy=graphical-session.target" "$F/xinguos-foco.service"
}

@test "kwinrc do sistema liga o script" {
  grep -qx "\[Plugins\]" "$F/kwinrc"
  grep -qx "xinguos-focoEnabled=true" "$F/kwinrc"
  grep -q '"Id": "xinguos-foco"' "$F/kwin/xinguos-foco/metadata.json"
  python3 -m json.tool "$F/kwin/xinguos-foco/metadata.json" >/dev/null
}

@test "wrappers usam PYTHONPATH /usr/lib/xinguos/foco" {
  grep -qx 'exec env PYTHONPATH=/usr/lib/xinguos/foco python3 -m xinguos_foco "$@"' "$F/xinguos-foco"
  grep -qx 'exec env PYTHONPATH=/usr/lib/xinguos/foco python3 -m xinguos_foco_painel "$@"' "$F/xinguos-foco-painel"
}

@test "pacote instala tudo nos caminhos certos e liga o serviço" {
  for p in /usr/lib/xinguos/foco /usr/bin/xinguos-foco /usr/bin/xinguos-foco-painel \
           /usr/share/kwin/scripts/xinguos-foco /etc/xdg/xinguos/foco.toml /etc/xdg/kwinrc \
           /usr/lib/systemd/user/xinguos-foco.service /usr/share/applications/org.xinguos.foco.desktop; do
    grep -q "$p" "$F/PKGBUILD"
  done
  run bash -c "source $F/PKGBUILD; printf '%s\n' \"\${depends[@]}\" \"\${backup[@]}\""
  for d in python python-dbus-fast pyside6 swayidle etc/xdg/xinguos/foco.toml; do grep -qx "$d" <<<"$output"; done
  grep -q "systemctl --global enable xinguos-foco.service" "$F/xinguos-foco.install"
}

@test "atalho do painel no launcher" {
  run desktop-file-validate "$F/org.xinguos.foco.desktop"
  echo "$output"
  [ "$status" -eq 0 ]
  grep -qx "Exec=xinguos-foco-painel" "$F/org.xinguos.foco.desktop"
}
