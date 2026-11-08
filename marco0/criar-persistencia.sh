#!/usr/bin/env bash
# Cria a persistência da ISO de teste do XInguOS no HD do Ventoy.
# Roda NO LIVE da própria ISO, como root:  sudo criar-persistencia
#
# uso: criar-persistencia [--raiz <dir>] [--tamanho <tamanho>]
#   --raiz     raiz da partição de dados do Ventoy (padrão: monta /dev/disk/by-label/Ventoy em /mnt/ventoy)
#   --tamanho  tamanho da imagem (padrão: 80G)
#
# Cria <raiz>/persistence/xinguos-teste.dat (ext4, rótulo vtoycow) e liga ela à
# /isos/Linux/xinguos-teste.iso no ventoy.json, preservando o resto do arquivo.
# Nunca recria uma imagem existente (isso apagaria a persistência).
set -euo pipefail

die() { echo "criar-persistencia: $*" >&2; exit 1; }

IMAGEM_ISO=/isos/Linux/xinguos-teste.iso
BACKEND=/persistence/xinguos-teste.dat

raiz=""
tamanho=80G
while [ $# -gt 0 ]; do
  case "$1" in
    --raiz) raiz=${2:?}; shift 2 ;;
    --tamanho) tamanho=${2:?}; shift 2 ;;
    *) die "opção desconhecida: $1" ;;
  esac
done

if [ -z "$raiz" ]; then
  dev=/dev/disk/by-label/Ventoy
  [ -e "$dev" ] || die "não achei a partição do Ventoy ($dev)"
  raiz=/mnt/ventoy
  mkdir -p "$raiz"
  if ! mountpoint -q "$raiz" && ! mount "$dev" "$raiz"; then
    die "não consegui montar $dev. No Windows, acrescente { \"VTOY_LINUX_REMOUNT\": \"1\" } à lista \"control\" de D:\\ventoy\\ventoy.json, reinicie e rode de novo."
  fi
fi

dat="$raiz$BACKEND"
json="$raiz/ventoy/ventoy.json"
[ ! -e "$dat" ] || die "$dat já existe: recriar apagaria a persistência. Nada foi alterado."

mkdir -p "$(dirname "$dat")" "$(dirname "$json")"
if [ -f "$json" ] && [ ! -e "$json.antes-xinguos" ]; then
  cp "$json" "$json.antes-xinguos"
fi

echo "criando $dat ($tamanho); no HD USB isso pode levar uns 20 minutos..."
fallocate -l "$tamanho" "$dat" 2>/dev/null || truncate -s "$tamanho" "$dat"
mkfs.ext4 -q -F -L vtoycow "$dat"

python3 - "$json" "$IMAGEM_ISO" "$BACKEND" <<'PY'
import json, sys
caminho, imagem, backend = sys.argv[1:4]
try:
    with open(caminho, encoding="utf-8-sig") as f:
        dados = json.load(f)
except FileNotFoundError:
    dados = {}
lista = [e for e in dados.get("persistence", []) if e.get("image") != imagem]
lista.append({"image": imagem, "backend": backend})
dados["persistence"] = lista
with open(caminho, "w", encoding="utf-8") as f:
    json.dump(dados, f, indent=4, ensure_ascii=False)
    f.write("\n")
print(f'ventoy.json: {{"image": "{imagem}", "backend": "{backend}"}}')
PY

sync
echo "pronto: rótulo $(e2label "$dat"). Reinicie, escolha xinguos-teste.iso e depois xinguos-teste.dat."
