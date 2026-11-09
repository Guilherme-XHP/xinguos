#!/usr/bin/env bats
# Tema escuro do XInguOS (Materia + Tela) e identidade XHP do Xingu: vinho #640000.

D=packages/xinguos/xinguos-desktop
LNF=$D/look-and-feel/org.xinguos.desktop
TEMA=packages/xinguos/xinguos-tema
B=packages/xinguos/xinguos-branding
CORES=$TEMA/XInguOSEscuro.colors

# valor de <chave> no grupo [<grupo>] de um arquivo KConfig
valor() { awk -v g="[$2]" -v k="$3" '$0 == g { em = 1; next } /^\[/ { em = 0 } em && index($0, k "=") == 1 { print substr($0, length(k) + 2) }' "$1"; }

@test "esquema XInguOS Escuro: fundo escuro e seleção no vinho #640000" {
  [ "$(valor "$CORES" General ColorScheme)" = XInguOSEscuro ]
  [ "$(valor "$CORES" General Name)" = "XInguOS Escuro" ]
  [ "$(valor "$CORES" Colors:Selection BackgroundNormal)" = "100,0,0" ]
  [ "$(valor "$CORES" Colors:Selection ForegroundNormal)" = "255,255,255" ]
  # fundo escuro de verdade (Materia Dark)
  [ "$(valor "$CORES" Colors:Window BackgroundNormal)" = "18,18,18" ]
  [ "$(valor "$CORES" Colors:View BackgroundNormal)" = "30,30,30" ]
  # nenhum resto do azul do Materia
  run grep -E '138,180,248|26,115,232|61,174,233|73,83,99' "$CORES"
  [ "$status" -ne 0 ]
}

@test "kdeglobals do sistema já traz as cores do esquema (vale para qualquer usuário novo)" {
  local k=$D/etc-xdg/kdeglobals
  [ "$(valor "$k" General ColorScheme)" = XInguOSEscuro ]
  # o AccentColor sobrescreveria o esquema inteiro (inclusive o foco): não fica
  run grep -q '^AccentColor=' "$k"
  [ "$status" -ne 0 ]
  for g in Button Selection Tooltip View Window Complementary; do
    for c in BackgroundNormal BackgroundAlternate ForegroundNormal DecorationFocus ForegroundLink; do
      [ "$(valor "$k" "Colors:$g" "$c")" = "$(valor "$CORES" "Colors:$g" "$c")" ] || { echo "difere: [Colors:$g] $c"; false; }
    done
  done
  [ "$(valor "$k" WM activeBackground)" = "$(valor "$CORES" WM activeBackground)" ]
  [ "$(valor "$k" Icons Theme)" = Tela-XInguOS-dark ]
}

@test "Plasma usa o Materia-Color (segue o esquema) e o Global Theme combina" {
  [ "$(valor "$D/etc-xdg/plasmarc" Theme name)" = Materia-Color ]
  local def=$LNF/contents/defaults
  [ "$(valor "$def" kdeglobals][General ColorScheme)" = XInguOSEscuro ]
  [ "$(valor "$def" kdeglobals][Icons Theme)" = Tela-XInguOS-dark ]
  [ "$(valor "$def" plasmarc][Theme name)" = Materia-Color ]
  [ "$(valor "$def" kwinrc][org.kde.kdecoration2 library)" = org.kde.kwin.aurorae ]
  [ "$(valor "$def" kwinrc][org.kde.kdecoration2 theme)" = __aurorae__svg__Materia-Dark ]
}

@test "primeiro login aplica a decoração Materia-Dark (o /etc/xdg/kwinrc é do xinguos-foco)" {
  grep -qF -- '--file kwinrc --group org.kde.kdecoration2 --key library org.kde.kwin.aurorae' "$D/xinguos-primeiro-login"
  grep -qF -- '--file kwinrc --group org.kde.kdecoration2 --key theme __aurorae__svg__Materia-Dark' "$D/xinguos-primeiro-login"
}

@test "barra do topo fina, estilo Mac (24 px)" {
  grep -qx 'topo.height = 24;' "$LNF/contents/layouts/org.kde.plasma.desktop-layout.js"
}

@test "pacote xinguos-tema: Tela e Materia com fonte fixa e sha256, e o esquema de cores" {
  run bash -c "source $TEMA/PKGBUILD; echo \"\$arch\"; printf '%s\n' \"\${source[@]}\"; printf '%s\n' \"\${sha256sums[@]}\"; printf '%s\n' \"\${conflicts[@]}\""
  echo "$output"
  [ "${lines[0]}" = any ]
  grep -q 'Tela-icon-theme/archive/refs/tags/' <<<"$output"
  grep -q 'materia-kde/archive/refs/tags/' <<<"$output"
  # todo download tem sha256 de verdade (só os arquivos locais ficam SKIP)
  [ "$(grep -cE '^[0-9a-f]{64}$' <<<"$output")" -eq 2 ]
  grep -qx materia-kde <<<"$output"
  grep -q 'Tela-XInguOS' "$TEMA/PKGBUILD"
  grep -q 'desktoptheme/Materia-Color' "$TEMA/PKGBUILD"
  grep -q 'aurorae/themes/Materia-Dark' "$TEMA/PKGBUILD"
  grep -q 'color-schemes/XInguOSEscuro.colors' "$TEMA/PKGBUILD"
}

@test "xinguos-desktop depende do xinguos-tema, que vem antes no ordem.txt" {
  run bash -c "source $D/PKGBUILD; printf '%s\n' \"\${depends[@]}\""
  grep -qx xinguos-tema <<<"$output"
  t=$(grep -nx 'xinguos/xinguos-tema' packages/ordem.txt | cut -d: -f1)
  d=$(grep -nx 'xinguos/xinguos-desktop' packages/ordem.txt | cut -d: -f1)
  [ -n "$t" ] && [ "$t" -lt "$d" ]
}

@test "identidade XHP: logo, wallpaper, instalador e terminal no vinho, sem o turquesa antigo" {
  grep -q '#640000' "$B/logo/xinguos.svg"
  grep -q '#640000' "$B/wallpaper/XInguOS/contents/images/1920x1080.svg"
  cmp -s "$B/logo/xinguos.svg" iso/instalar/calamares/branding/xinguos/logo.svg
  grep -qx '  SidebarBackgroundCurrent: "#640000"' iso/instalar/calamares/branding/xinguos/branding.desc
  [ -f "$B/logo/Logo_XHP.png" ]
  run grep -rniE '2ec4b6|5eead4|46,196,182|46;196;182' "$B" "$D" iso/instalar/calamares
  echo "$output"
  [ "$status" -ne 0 ]
}
