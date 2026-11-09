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
# .git e o .gitignore do repositório AUR (que costuma ignorar "*" e esconderia arquivos do nosso git)
rm -rf "$tmp/clone/.git" "$tmp/clone/.gitignore"

# pacotes -git: o PKGBUILD do AUR baixa o HEAD do upstream. Com um pin em <raiz>/aur-pins.txt
# ("<pkgbase> <commit>"), a source fica fixada nesse commit, para nunca assinar código não revisado.
pin=""
if [ -f "$raiz/aur-pins.txt" ]; then
  pin=$(awk -v p="$pkgbase" '$1==p {print $2}' "$raiz/aur-pins.txt")
fi
if [ -n "$pin" ]; then
  [[ "$pin" =~ ^[0-9a-f]{40}$ ]] || die "pin inválido para $pkgbase: $pin"
  grep -qE 'git\+[^"#]+' "$tmp/clone/PKGBUILD" || die "pin de $pkgbase: PKGBUILD sem source git+ para fixar"
  sed -i -E "s|(git\+[^\"'# )]+)([\"' )])|\1#commit=$pin\2|" "$tmp/clone/PKGBUILD"
  grep -qF "#commit=$pin" "$tmp/clone/PKGBUILD" || die "pin de $pkgbase não foi aplicado"
fi

destino="$raiz/aur/$pkgbase"
rm -rf "$destino"
mkdir -p "$destino"
cp -r "$tmp/clone/." "$destino/"
echo "$commit" > "$destino/.aur-commit"
echo "sync-aur: $pkgbase em $destino (commit $commit)"
