#!/usr/bin/env bats

G=packages/xinguos/xinguos-gaming

setup() {
  T=$(mktemp -d)
  export LOG="$T/log" XINGUOS_SDDM_DIR="$T/sddm" XINGUOS_ETC="$T/etc" XINGUOS_SESSOES="$T/sessoes"
  export XINGUOS_HELPER="$PWD/$G/xinguos-sessao-root" XINGUOS_ESTADO="$T/estado"
  export PATH="$PWD/tests/stubs-gaming:$PATH" XDG_SESSION_ID=7 PKEXEC_UID=1000
  mkdir -p "$XINGUOS_SESSOES"
  touch "$XINGUOS_SESSOES/plasma.desktop" "$XINGUOS_SESSOES/xinguos-gaming.desktop"
  : > "$LOG"
}

teardown() { rm -rf "$T"; }

autologin() { cat "$XINGUOS_SDDM_DIR/zz-xinguos-session.conf"; }

# --- Task 1: troca de sessão ---

@test "gaming: grava o autologin na sessão Gaming e encerra a sessão atual" {
  run bash "$G/xinguos-session-select" gaming
  echo "$output"
  [ "$status" -eq 0 ]
  autologin | grep -qx "User=xingu"
  autologin | grep -qx "Session=xinguos-gaming.desktop"
  autologin | grep -qx "Relogin=true"
  grep -qx "loginctl terminate-session 7" "$LOG"
}

@test "plasma (botão do Steam) e desktop voltam para o Plasma" {
  for a in plasma desktop plasma-wayland-persistent; do
    run bash "$G/xinguos-session-select" "$a"
    [ "$status" -eq 0 ]
    autologin | grep -qx "Session=plasma.desktop"
  done
}

@test "argumento inválido não grava nada" {
  run bash "$G/xinguos-session-select" banana
  [ "$status" -eq 2 ]
  [ ! -e "$XINGUOS_SDDM_DIR/zz-xinguos-session.conf" ]
  run grep -q loginctl "$LOG"
  [ "$status" -ne 0 ]
}

@test "helper recusa sessão inexistente, nome perigoso e usuário de outra pessoa" {
  run bash "$XINGUOS_HELPER" sessao xingu nao-existe.desktop
  [ "$status" -ne 0 ]
  run bash "$XINGUOS_HELPER" sessao xingu ../../etc/passwd
  [ "$status" -ne 0 ]
  run bash "$XINGUOS_HELPER" sessao outro plasma.desktop
  [ "$status" -ne 0 ]
  [ ! -e "$XINGUOS_SDDM_DIR/zz-xinguos-session.conf" ]
}

@test "--default e --modo gravam a escolha; --status mostra" {
  run bash "$G/xinguos-session-select" --status
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "padrao=ultima" ]
  [ "${lines[1]}" = "modo=compativel" ]
  run bash "$G/xinguos-session-select" --default gaming
  [ "$status" -eq 0 ]
  grep -qx "PADRAO=gaming" "$XINGUOS_ETC/sessao.conf"
  run bash "$G/xinguos-session-select" --modo completo
  [ "$status" -eq 0 ]
  grep -qx "MODO_GAMING=completo" "$XINGUOS_ETC/gaming.conf"
  run grep -q "gerado" "$XINGUOS_ETC/gaming.conf"
  [ "$status" -ne 0 ]
  run bash "$G/xinguos-session-select" --status
  [ "${lines[0]}" = "padrao=gaming" ]
  [ "${lines[1]}" = "modo=completo" ]
  run bash "$G/xinguos-session-select" --modo turbo
  [ "$status" -ne 0 ]
}

@test "boot: sessão padrão fixa troca o autologin; 'ultima' não mexe" {
  bash "$G/xinguos-session-select" gaming
  echo "PADRAO=desktop" > "$XINGUOS_ETC/sessao.conf" 2>/dev/null || { mkdir -p "$XINGUOS_ETC"; echo "PADRAO=desktop" > "$XINGUOS_ETC/sessao.conf"; }
  run bash "$G/xinguos-sessao-boot"
  [ "$status" -eq 0 ]
  autologin | grep -qx "Session=plasma.desktop"
  bash "$G/xinguos-session-select" gaming
  echo "PADRAO=ultima" > "$XINGUOS_ETC/sessao.conf"
  run bash "$G/xinguos-sessao-boot"
  autologin | grep -qx "Session=xinguos-gaming.desktop"
  rm -rf "$XINGUOS_SDDM_DIR"
  run bash "$G/xinguos-sessao-boot"
  [ "$status" -eq 0 ]
  [ ! -e "$XINGUOS_SDDM_DIR/zz-xinguos-session.conf" ]
}

@test "polkit libera só o helper, só para wheel em sessão local ativa" {
  grep -q '"org.xinguos.sessao"' "$G/49-xinguos-sessao.rules"
  grep -q 'subject.isInGroup("wheel")' "$G/49-xinguos-sessao.rules"
  grep -q 'subject.active' "$G/49-xinguos-sessao.rules"
  grep -q 'subject.local' "$G/49-xinguos-sessao.rules"
  python3 -c 'import sys, xml.dom.minidom as m; m.parse(sys.argv[1])' "$G/org.xinguos.sessao.policy"
  grep -q '<annotate key="org.freedesktop.policykit.exec.path">/usr/lib/xinguos/xinguos-sessao-root</annotate>' "$G/org.xinguos.sessao.policy"
}

@test "os-session-select (gancho do steamos-session-select) repassa para o xinguos-session-select" {
  grep -qx 'exec /usr/bin/xinguos-session-select "$@"' "$G/os-session-select"
}

# --- Task 2: sessão Gaming + contador de falhas ---

sessao() {  # sessao <rc> <duração>
  export RELOGIO="$T/relogio" FAKE_RC=$1
  printf '1000\n%s\n' "$((1000 + $2))" > "$RELOGIO"
  PATH="$PWD/tests/stubs-gaming:$T/bin:$PATH" run bash "$G/xinguos-gaming-sessao"
}

@test "modo compatível (padrão) abre o Steam em tela cheia no KWin; completo usa o gamescope" {
  mkdir -p "$T/bin"; printf '#!/usr/bin/env bash\necho "xinguos-session-select $*" >> "%s"\n' "$LOG" > "$T/bin/xinguos-session-select"; chmod +x "$T/bin/xinguos-session-select"
  sessao 0 600
  [ "$status" -eq 0 ]
  grep -qx 'kwin_wayland --xwayland --exit-with-session /usr/lib/xinguos/xinguos-steam-compativel' "$LOG"
  mkdir -p "$XINGUOS_ETC"; echo "MODO_GAMING=completo" > "$XINGUOS_ETC/gaming.conf"
  sessao 0 600
  grep -qx 'gamescope-session-plus steam' "$LOG"
}

@test "2 falhas rápidas seguidas: volta para o Desktop e deixa o aviso" {
  mkdir -p "$T/bin"; printf '#!/usr/bin/env bash\necho "xinguos-session-select $*" >> "%s"\n' "$LOG" > "$T/bin/xinguos-session-select"; chmod +x "$T/bin/xinguos-session-select"
  sessao 1 5
  [ "$status" -eq 1 ]
  [ "$(cat "$XINGUOS_ESTADO/gaming-falhas")" = 1 ]
  run grep -q "xinguos-session-select --proxima desktop" "$LOG"
  [ "$status" -ne 0 ]
  sessao 1 5
  grep -qx "xinguos-session-select --proxima desktop" "$LOG"
  [ -e "$XINGUOS_ESTADO/gaming-aviso" ]
  [ "$(cat "$XINGUOS_ESTADO/gaming-falhas")" = 0 ]
}

@test "sessão longa zera o contador; sair do Steam leva para a Área de Trabalho" {
  mkdir -p "$T/bin"; printf '#!/usr/bin/env bash\necho "xinguos-session-select $*" >> "%s"\n' "$LOG" > "$T/bin/xinguos-session-select"; chmod +x "$T/bin/xinguos-session-select"
  sessao 1 5
  sessao 0 300
  [ "$(cat "$XINGUOS_ESTADO/gaming-falhas")" = 0 ]
  grep -qx "xinguos-session-select --proxima desktop" "$LOG"
  [ ! -e "$XINGUOS_ESTADO/gaming-aviso" ]
}

@test "queda rápida conta mesmo com saída 0 (o gamescope-session-plus sempre sai 0)" {
  mkdir -p "$T/bin"; printf '#!/usr/bin/env bash\necho "xinguos-session-select $*" >> "%s"\n' "$LOG" > "$T/bin/xinguos-session-select"; chmod +x "$T/bin/xinguos-session-select"
  mkdir -p "$XINGUOS_ETC"; echo "MODO_GAMING=completo" > "$XINGUOS_ETC/gaming.conf"
  sessao 0 4
  [ "$(cat "$XINGUOS_ESTADO/gaming-falhas")" = 1 ]
  sessao 0 4
  grep -qx "xinguos-session-select --proxima desktop" "$LOG"
  [ -e "$XINGUOS_ESTADO/gaming-aviso" ]
}

@test "troca pedida (Mudar para a Área de Trabalho) não conta como falha" {
  mkdir -p "$T/bin"; printf '#!/usr/bin/env bash\necho "xinguos-session-select $*" >> "%s"\n' "$LOG" > "$T/bin/xinguos-session-select"; chmod +x "$T/bin/xinguos-session-select"
  mkdir -p "$XINGUOS_ESTADO"; echo 1 > "$XINGUOS_ESTADO/gaming-falhas"
  # marca velha (da troca Plasma → Gaming) é limpa no começo; a que vale é a criada durante a sessão
  touch "$XINGUOS_ESTADO/troca-pedida"
  FAKE_TROCA="$XINGUOS_ESTADO/troca-pedida" sessao 0 4
  [ "$(cat "$XINGUOS_ESTADO/gaming-falhas")" = 0 ]
  [ ! -e "$XINGUOS_ESTADO/troca-pedida" ]
  run grep -q "xinguos-session-select" "$LOG"
  [ "$status" -ne 0 ]
}

@test "no Desktop, o aviso aparece uma vez e some" {
  mkdir -p "$XINGUOS_ESTADO"; touch "$XINGUOS_ESTADO/gaming-aviso"
  run bash "$G/xinguos-gaming-aviso"
  [ "$status" -eq 0 ]
  grep -q "^notify-send" "$LOG"
  [ ! -e "$XINGUOS_ESTADO/gaming-aviso" ]
  : > "$LOG"
  run bash "$G/xinguos-gaming-aviso"
  [ ! -s "$LOG" ]
}

@test "sessão XInguOS Gaming registrada no SDDM" {
  grep -qx "Exec=/usr/lib/xinguos/xinguos-gaming-sessao" "$G/xinguos-gaming.desktop"
  grep -qx "Name=XInguOS Gaming" "$G/xinguos-gaming.desktop"
}

# --- Task 3: pacotes ---

@test "pacote xinguos-gaming instala tudo nos caminhos certos" {
  for p in /usr/bin/xinguos-session-select /usr/lib/os-session-select /usr/lib/xinguos/xinguos-sessao-root \
           /usr/lib/xinguos/xinguos-gaming-sessao /usr/share/polkit-1/rules.d/49-xinguos-sessao.rules \
           /usr/share/polkit-1/actions/org.xinguos.sessao.policy /usr/share/wayland-sessions/xinguos-gaming.desktop \
           /usr/lib/systemd/system/xinguos-sessao-boot.service /usr/share/applications/org.xinguos.gaming.desktop \
           /etc/xdg/autostart/xinguos-gaming-aviso.desktop /etc/skel/.config/MangoHud/MangoHud.conf; do
    grep -q "$p" "$G/PKGBUILD" || { echo "falta $p"; false; }
  done
  run bash -c "source $G/PKGBUILD; printf '%s\n' \"\${depends[@]}\""
  for d in steam gamescope-session-steam-git mangohud lib32-mangohud gamemode lib32-gamemode polkit; do
    grep -qx "$d" <<<"$output" || { echo "falta depends $d"; false; }
  done
  grep -q "systemctl enable xinguos-sessao-boot.service" "$G/xinguos-gaming.install"
}

@test "Win+Shift+G volta ao Gaming Mode; MangoHud começa escondido com Shift+F12" {
  grep -qx "X-KDE-Shortcuts=Meta+Shift+G" "$G/org.xinguos.gaming.desktop"
  grep -qx "Exec=xinguos-session-select gaming" "$G/org.xinguos.gaming.desktop"
  grep -qx "no_display" "$G/MangoHud.conf"
  grep -qx "toggle_hud=Shift_L+F12" "$G/MangoHud.conf"
}

@test "metapacote xinguos puxa tudo menos os apps pesados; ordem de build certa" {
  run bash -c "source packages/xinguos/xinguos/PKGBUILD; printf '%s\n' \"\${depends[@]}\""
  for d in xinguos-base xinguos-kernels xinguos-desktop xinguos-gaming xinguos-boasvindas xinguos-branding; do
    grep -qx "$d" <<<"$output"
  done
  run grep -x xinguos-apps <<<"$output"
  [ "$status" -ne 0 ]
  g=$(grep -nx 'xinguos/xinguos-gaming' packages/ordem.txt | cut -d: -f1)
  m=$(grep -nx 'xinguos/xinguos' packages/ordem.txt | cut -d: -f1)
  s=$(grep -nx 'aur/gamescope-session-steam-git' packages/ordem.txt | cut -d: -f1)
  [ -n "$g" ] && [ -n "$m" ] && [ "$s" -lt "$g" ] && [ "$g" -lt "$m" ]
  [ "$m" -eq "$(grep -cv '^\s*$' packages/ordem.txt)" ]
}

# --- correções da revisão final ---

@test "troca pelo Plasma faz logout educado (apps podem salvar) e marca a troca pedida" {
  mkdir -p "$T/bin"
  printf '#!/usr/bin/env bash\necho "qdbus6 $*" >> "%s"\n' "$LOG" > "$T/bin/qdbus6"; chmod +x "$T/bin/qdbus6"
  PATH="$T/bin:$PATH" XDG_CURRENT_DESKTOP=KDE run bash "$G/xinguos-session-select" gaming
  [ "$status" -eq 0 ]
  grep -qx "qdbus6 org.kde.Shutdown /Shutdown logout" "$LOG"
  run grep -q "loginctl" "$LOG"
  [ "$status" -ne 0 ]
  [ -e "$XINGUOS_ESTADO/troca-pedida" ]
  autologin | grep -qx "Session=xinguos-gaming.desktop"
}

@test "troca pelo Gaming fecha o Steam direito (steam -shutdown)" {
  mkdir -p "$T/bin"
  printf '#!/usr/bin/env bash\necho "steam $*" >> "%s"\n' "$LOG" > "$T/bin/steam"; chmod +x "$T/bin/steam"
  PATH="$T/bin:$PATH" XDG_CURRENT_DESKTOP=gamescope:KDE XINGUOS_ESPERA_TROCA=0 run bash "$G/xinguos-session-select" plasma
  [ "$status" -eq 0 ]
  grep -qx "steam -shutdown" "$LOG"
  [ -e "$XINGUOS_ESTADO/troca-pedida" ]
  autologin | grep -qx "Session=plasma.desktop"
}

@test "--proxima só grava o autologin, sem encerrar nada" {
  run bash "$G/xinguos-session-select" --proxima desktop
  [ "$status" -eq 0 ]
  autologin | grep -qx "Session=plasma.desktop"
  run grep -qE "loginctl|steam|qdbus6" "$LOG"
  [ "$status" -ne 0 ]
}

@test "fixar Gaming ao ligar numa instalação nova já cria o login automático" {
  run bash "$G/xinguos-session-select" --default gaming
  [ "$status" -eq 0 ]
  autologin | grep -qx "User=xingu"
  autologin | grep -qx "Session=xinguos-gaming.desktop"
  rm -rf "$XINGUOS_SDDM_DIR"
  run bash "$G/xinguos-session-select" --default ultima
  [ ! -e "$XINGUOS_SDDM_DIR/zz-xinguos-session.conf" ]
}

@test "modo compatível: MangoHud escondido e Desligar/Reiniciar do Steam funcionam" {
  mkdir -p "$T/bin"
  printf '#!/usr/bin/env bash\necho "steam $* MANGOHUD=$MANGOHUD CFG=$MANGOHUD_CONFIGFILE" >> "%s"\ntouch "$STEAMOS_STEAM_SHUTDOWN_SENTINEL"\n' "$LOG" > "$T/bin/steam"
  printf '#!/usr/bin/env bash\necho "systemctl $*" >> "%s"\n' "$LOG" > "$T/bin/systemctl"
  printf '#!/usr/bin/env bash\nexit 0\n' > "$T/bin/dbus-update-activation-environment"
  chmod +x "$T/bin/"*
  HOME="$T/home" XINGUOS_SENTINELAS="$T" PATH="$T/bin:$PATH" run bash "$G/xinguos-steam-compativel"
  echo "$output"
  [ "$status" -eq 0 ]
  grep -qx "steam -gamepadui -steamos3 MANGOHUD=1 CFG=/usr/share/xinguos/MangoHud.conf" "$LOG"
  grep -qx "systemctl poweroff" "$LOG"
}

@test "Win+Shift+G registrado no kglobalaccel do Plasma 6" {
  grep -q 'usr/share/kglobalaccel/org.xinguos.gaming.desktop' "$G/PKGBUILD"
  grep -q '/usr/share/xinguos/MangoHud.conf' "$G/PKGBUILD"
  grep -q '/usr/lib/xinguos/xinguos-steam-compativel' "$G/PKGBUILD"
}
