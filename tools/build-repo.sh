#!/usr/bin/env bash
# Compila os pacotes listados em <arquivo-ordem>, assina tudo e monta o banco [xinguos].
#
# uso: build-repo.sh <arquivo-ordem> <raiz-pacotes> <dir-saida>
# ambiente: XINGUOS_GPG_FPR (obrigatório) — fingerprint da chave secreta que assina
#
# Roda como root (depois do tools/ci-setup.sh). O makepkg roda como o usuário "builder".
# Se algo falhar, nenhum xinguos.db é gerado: nunca se publica nada sem assinatura.
set -euo pipefail

die() { echo "build-repo: $*" >&2; exit 1; }

[ $# -eq 3 ] || die "uso: build-repo.sh <arquivo-ordem> <raiz-pacotes> <dir-saida>"
ordem=$1
raiz=$2
out=$3

fpr=${XINGUOS_GPG_FPR:-}
[ -n "$fpr" ] || die "XINGUOS_GPG_FPR não definido"
gpg --batch --list-secret-keys "$fpr" >/dev/null 2>&1 || die "chave secreta $fpr não está no keyring"
[ -f "$ordem" ] || die "arquivo de ordem não existe: $ordem"

mkdir -p "$out"
[ -z "$(ls -A "$out")" ] || die "diretório de saída não está vazio: $out"
out=$(cd "$out" && pwd)

trabalho=$(mktemp -d)
trap 'rm -rf "$trabalho"' EXIT
chown builder: "$trabalho"

while IFS= read -r linha || [ -n "$linha" ]; do
  case "$linha" in '' | '#'*) continue ;; esac
  [ -f "$raiz/$linha/PKGBUILD" ] || die "sem PKGBUILD em $raiz/$linha"
  dir="$trabalho/$(basename "$linha")"
  cp -r "$raiz/$linha" "$dir"
  chown -R builder: "$dir"
  echo "==> compilando $linha"
  # -i instala o resultado, para que os pacotes seguintes encontrem as dependências
  (cd "$dir" && sudo -u builder makepkg -si --noconfirm --cleanbuild) || die "makepkg falhou em $linha"
  for pkg in "$dir"/*.pkg.tar.zst; do
    namcap "$pkg" || echo "build-repo: aviso: namcap reclamou de $(basename "$pkg")" >&2
    mv "$pkg" "$out/"
  done
done < "$ordem"

shopt -s nullglob
pacotes=("$out"/*.pkg.tar.zst)
[ ${#pacotes[@]} -gt 0 ] || die "nenhum pacote foi gerado"

# o GitHub troca caracteres como ':' e '+' no nome dos assets, o que quebraria o pacman
for pkg in "${pacotes[@]}"; do
  nome=$(basename "$pkg")
  [[ "$nome" =~ ^[A-Za-z0-9._-]+$ ]] || die "nome de pacote inválido para GitHub Releases: $nome"
done

for pkg in "${pacotes[@]}"; do
  gpg --batch --yes --detach-sign -u "$fpr" "$pkg"
done

repo-add --sign --key "$fpr" "$out/xinguos.db.tar.gz" "${pacotes[@]}"

# GitHub Releases não guarda links simbólicos: troca por cópias reais
for f in xinguos.db xinguos.db.sig xinguos.files xinguos.files.sig; do
  if [ -L "$out/$f" ]; then
    alvo=$(readlink -f "$out/$f")
    rm "$out/$f"
    cp "$alvo" "$out/$f"
  fi
done
