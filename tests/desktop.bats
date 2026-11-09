#!/usr/bin/env bats

D=packages/xinguos/xinguos-desktop
LNF=$D/look-and-feel/org.xinguos.desktop
PL=$D/xinguos-primeiro-login

# --- Task 2: Global Theme ---

@test "layout.js é JS válido e cria os dois painéis com os widgets certos" {
  local js=$LNF/contents/layouts/org.kde.plasma.desktop-layout.js
  node --check "$js"
  grep -q 'location = "top"' "$js"
  grep -q 'location = "bottom"' "$js"
  grep -q '"org.kde.plasma.kickoff"' "$js"
  grep -q '"org.kde.plasma.appmenu"' "$js"
  grep -q '"org.kde.plasma.systemtray"' "$js"
  grep -q '"org.kde.plasma.digitalclock"' "$js"
  grep -q '"org.kde.plasma.icontasks"' "$js"
  grep -q 'hiding = "dodgewindows"' "$js"
  grep -q 'lengthMode = "fit"' "$js"
  grep -q 'applications:org.kde.dolphin.desktop' "$js"
  python3 -m json.tool "$LNF/metadata.json" >/dev/null
  grep -q '"Id": "org.xinguos.desktop"' "$LNF/metadata.json"
}

# --- Task 3: /etc/xdg ---

@test "configs de sistema: tema, animação, baloo e env script inofensivo" {
  grep -qx "LookAndFeelPackage=org.xinguos.desktop" "$D/etc-xdg/kdeglobals"
  grep -qx "AnimationDurationFactor=0.5" "$D/etc-xdg/kdeglobals"
  grep -qx "Indexing-Enabled=false" "$D/etc-xdg/baloofilerc"
  local env=$D/etc-xdg/plasma-workspace/env/xinguos-primeiro-login.sh
  [ "$(grep -cvE '^\s*(#|$)' "$env")" -eq 1 ]
  grep -qx '/usr/lib/xinguos/xinguos-primeiro-login || true' "$env"
  run grep -w exit "$env"
  [ "$status" -ne 0 ]
}

# --- Task 4: primeiro login ---

preparar_login() {
  export HOME="$BATS_TEST_TMPDIR/home"
  mkdir -p "$HOME/.config"
  export PATH="$BATS_TEST_DIRNAME/stubs:$PATH"
  export KWRITE_LOG="$BATS_TEST_TMPDIR/kwrite.log"
  : > "$KWRITE_LOG"
}

@test "primeira vez grava atalhos, krohnkite, dolphin e marca" {
  preparar_login
  run "$PL"
  echo "$output"
  [ "$status" -eq 0 ]
  grep -qF -- "--file kglobalshortcutsrc --group kwin --key Window Maximize Meta+Up,Meta+PgUp,Maximizar janela" "$KWRITE_LOG"
  grep -qF -- "--key KrohnkiteNextLayout Meta+T," "$KWRITE_LOG"
  grep -qF -- "--group services --group org.kde.krunner.desktop --key _launch Meta+R" "$KWRITE_LOG"
  grep -qF -- "--file kwinrc --group Plugins --key krohnkiteEnabled true" "$KWRITE_LOG"
  grep -qF -- "--key floatingLayoutOrder 1" "$KWRITE_LOG"
  grep -qF -- "--key tileLayoutOrder 2" "$KWRITE_LOG"
  grep -qF -- "--key monocleLayoutOrder 0" "$KWRITE_LOG"
  grep -qF -- "--file dolphinrc --group General --key EditableUrl true" "$KWRITE_LOG"
  grep -qF -- "--file kdeglobals --group KDE --key LookAndFeelPackage org.xinguos.desktop" "$KWRITE_LOG"
  grep -qF -- "kdenlive" "$KWRITE_LOG"
  grep -qx "ViewMode=1" "$HOME/.local/share/dolphin/view_properties/global/.directory"
  [ -f "$HOME/.local/state/xinguos/desktop-v1" ]
}

@test "atalhos do Krohnkite que brigam com os do Windows ficam none" {
  preparar_login
  "$PL"
  for k in KrohnkiteFocusRight KrohnkiteDecrease KrohnkiteIncrease KrohnkiteRotate KrohnkiteFocusNext KrohnkiteTileLayout; do
    grep -qF -- "--key $k none," "$KWRITE_LOG"
  done
}

@test "segunda vez não faz nada" {
  preparar_login
  mkdir -p "$HOME/.local/state/xinguos"
  touch "$HOME/.local/state/xinguos/desktop-v1"
  run "$PL"
  [ "$status" -eq 0 ]
  [ ! -s "$KWRITE_LOG" ]
}

@test "layout antigo do usuário vai para .antes-xinguos" {
  preparar_login
  echo velho > "$HOME/.config/plasma-org.kde.plasma.desktop-appletsrc"
  "$PL"
  [ "$(cat "$HOME/.config/plasma-org.kde.plasma.desktop-appletsrc.antes-xinguos")" = velho ]
  [ ! -e "$HOME/.config/plasma-org.kde.plasma.desktop-appletsrc" ]
}

@test "kwriteconfig6 falhando não impede o login" {
  preparar_login
  KWRITE_STATUS=1 run "$PL"
  echo "$output"
  [ "$status" -eq 0 ]
  [[ "$output" == *"aviso:"* ]]
  [ -f "$HOME/.local/state/xinguos/desktop-v1" ]
}

# --- Task 5: pacotes ---

deps() { bash -c "source $1; printf '%s\n' \"\${depends[@]}\""; }

@test "xinguos-desktop não depende de kdeconnect nem de plasma-meta" {
  run deps "$D/PKGBUILD"
  [ "$status" -eq 0 ]
  grep -qx plasma-desktop <<<"$output"
  grep -qx kwin-scripts-krohnkite <<<"$output"
  run grep -xE 'kdeconnect|plasma|plasma-meta' <<<"$output"
  [ "$status" -ne 0 ]
}

@test "xinguos-apps tem a lista da spec 8.1" {
  run deps packages/xinguos/xinguos-apps/PKGBUILD
  for p in firefox firefox-i18n-pt-br telegram-desktop vlc kdenlive obs-studio audacity gimp blender godot code git android-tools python nodejs npm jdk17-openjdk jdk21-openjdk base-devel gcc gdb cmake clang libreoffice-fresh libreoffice-fresh-pt-br qbittorrent 7zip bitwarden obsidian; do
    grep -qx "$p" <<<"$output" || { echo "falta $p"; return 1; }
  done
}

@test "env script e primeiro-login vão para os caminhos certos" {
  grep -qF '/etc/xdg/plasma-workspace/env/xinguos-primeiro-login.sh' "$D/PKGBUILD"
  grep -qF '/usr/lib/xinguos/xinguos-primeiro-login' "$D/PKGBUILD"
  grep -qF '/usr/share/plasma/look-and-feel/org.xinguos.desktop' "$D/PKGBUILD"
}
