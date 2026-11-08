#!/usr/bin/env bash
# Publica o conteúdo de <dir-saida> (gerado pelo build-repo.sh) como assets da release <tag>.
#
# uso: publish-release.sh <dir-saida> <tag>
# ambiente: GH_TOKEN e GH_REPO (lidos pelo gh)
#
# Ordem importa: pacotes e assinaturas sobem primeiro e o banco por último. Assim, se o
# upload parar no meio, o banco publicado nunca aponta para um pacote que não existe.
# No fim, apaga da release os assets que não estão mais em <dir-saida> (versões antigas).
set -euo pipefail

die() { echo "publish-release: $*" >&2; exit 1; }

[ $# -eq 2 ] || die "uso: publish-release.sh <dir-saida> <tag>"
out=$1
tag=$2
[ -d "$out" ] || die "diretório não existe: $out"

bancos=()
for f in xinguos.db xinguos.db.sig xinguos.files xinguos.files.sig; do
  [ -f "$out/$f" ] || die "falta $f em $out"
  bancos+=("$out/$f")
done

shopt -s nullglob
arquivos=("$out"/*.pkg.tar.zst "$out"/*.pkg.tar.zst.sig)
[ ${#arquivos[@]} -gt 0 ] || die "nenhum pacote em $out"
[ -f "$out/xinguos.gpg" ] && arquivos+=("$out/xinguos.gpg")

if ! gh release view "$tag" >/dev/null 2>&1; then
  gh release create "$tag" --title "Repositório pacman [xinguos]" \
    --notes "Repositório pacman do XInguOS. Não baixe à mão: veja o README." --latest=false
fi

existentes=$(gh release view "$tag" --json assets -q '.assets[].name')

# nome de pacote é imutável: o que já está publicado nunca é reenviado nem sobrescrito
# (o build-repo reaproveita os mesmos bytes, então o banco novo continua batendo)
novos=()
for f in "${arquivos[@]}"; do
  grep -qxF "$(basename "$f")" <<<"$existentes" || novos+=("$f")
done
if [ ${#novos[@]} -gt 0 ]; then
  gh release upload "$tag" "${novos[@]}"
fi
gh release upload "$tag" --clobber "${bancos[@]}"

while IFS= read -r nome; do
  [ -n "$nome" ] || continue
  [ -e "$out/$nome" ] || gh release delete-asset "$tag" "$nome" -y
done <<<"$existentes"
