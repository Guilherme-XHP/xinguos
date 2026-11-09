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
