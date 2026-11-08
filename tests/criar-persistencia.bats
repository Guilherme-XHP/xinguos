#!/usr/bin/env bats

setup() {
  R="$BATS_TEST_TMPDIR/ventoy"
  mkdir -p "$R/ventoy"
  # ventoy.json real do Xingu (D:\ventoy\ventoy.json em 2026-11-08)
  cat > "$R/ventoy/ventoy.json" <<'JSON'
{
    "control":[
        { "VTOY_DEFAULT_SEARCH_ROOT": "/isos" }
    ],
    "theme":{
        "display_mode": "CLI"
    }
}
JSON
  cp "$R/ventoy/ventoy.json" "$BATS_TEST_TMPDIR/original.json"
  DAT="$R/persistence/xinguos-teste.dat"
}

@test "cria imagem ext4 com rótulo vtoycow" {
  run marco0/criar-persistencia.sh --raiz "$R" --tamanho 64M
  echo "$output"
  [ "$status" -eq 0 ]
  [ "$(e2label "$DAT")" = vtoycow ]
}

@test "preserva control e theme e acrescenta persistence" {
  marco0/criar-persistencia.sh --raiz "$R" --tamanho 64M
  python3 - "$R/ventoy/ventoy.json" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
assert d["control"][0]["VTOY_DEFAULT_SEARCH_ROOT"] == "/isos"
assert d["theme"]["display_mode"] == "CLI"
assert d["persistence"] == [{"image": "/isos/Linux/xinguos-teste.iso", "backend": "/persistence/xinguos-teste.dat"}]
PY
}

@test "rodar duas vezes não duplica nem apaga" {
  marco0/criar-persistencia.sh --raiz "$R" --tamanho 64M
  antes=$(stat -c %Y "$DAT")
  run marco0/criar-persistencia.sh --raiz "$R" --tamanho 64M
  [ "$status" -eq 1 ]
  [ "$(stat -c %Y "$DAT")" = "$antes" ]
  n=$(python3 -c 'import json,sys; print(len(json.load(open(sys.argv[1]))["persistence"]))' "$R/ventoy/ventoy.json")
  [ "$n" -eq 1 ]
}

@test "faz backup do ventoy.json" {
  marco0/criar-persistencia.sh --raiz "$R" --tamanho 64M
  cmp "$BATS_TEST_TMPDIR/original.json" "$R/ventoy/ventoy.json.antes-xinguos"
}
