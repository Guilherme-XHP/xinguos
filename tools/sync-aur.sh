#!/usr/bin/env bash
# Copia (vendoriza) um pkgbase do AUR para <raiz>/aur/<pkgbase>/, sem o .git,
# gravando o commit de origem em .aur-commit.
#
# uso: sync-aur.sh <pkgbase> [raiz-pacotes]   (raiz padrão: packages)
# ambiente: AUR_GIT_BASE (padrão https://aur.archlinux.org) — usado nos testes
#
# Se o clone falhar ou vier sem PKGBUILD (o AUR devolve repositório vazio para
# nomes inexistentes), a cópia atual não é tocada.
set -euo pipefail

die() { echo "sync-aur: $*" >&2; exit 1; }

[ $# -ge 1 ] && [ $# -le 2 ] || die "uso: sync-aur.sh <pkgbase> [raiz-pacotes]"
pkgbase=$1
raiz=${2:-packages}
base=${AUR_GIT_BASE:-https://aur.archlinux.org}

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

git clone -q "$base/$pkgbase.git" "$tmp/clone" 2>/dev/null || die "não consegui clonar $base/$pkgbase.git"
[ -f "$tmp/clone/PKGBUILD" ] || die "$pkgbase não tem PKGBUILD (pkgbase inexistente?)"
commit=$(git -C "$tmp/clone" rev-parse HEAD)
rm -rf "$tmp/clone/.git"

destino="$raiz/aur/$pkgbase"
rm -rf "$destino"
mkdir -p "$destino"
cp -r "$tmp/clone/." "$destino/"
echo "$commit" > "$destino/.aur-commit"
echo "sync-aur: $pkgbase em $destino (commit $commit)"
