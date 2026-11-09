#!/usr/bin/env bash
# Compila os pacotes listados em <arquivo-ordem>, assina tudo e monta o banco [xinguos].
#
# uso: build-repo.sh <arquivo-ordem> <raiz-pacotes> <dir-saida>
# ambiente: XINGUOS_GPG_FPR (obrigatório) — fingerprint da chave secreta que assina
#           XINGUOS_PUBLICADOS (opcional) — pasta com os pacotes já publicados (+ .sig).
#           Nome de pacote é imutável: se o mesmo arquivo já foi publicado, os bytes
#           publicados são reaproveitados no lugar da recompilação (que mudaria o checksum).
#
# Roda como root (depois do tools/ci-setup.sh). O makepkg roda como o usuário "builder".
# Se algo falhar, nenhum xinguos.db é gerado: nunca se publica nada sem assinatura.
set -euo pipefail

die() { echo "build-repo: $*" >&2; exit 1; }

# Impressão digital do CONTEÚDO de um pacote, ignorando o que muda a cada build.
# Usa o .MTREE (caminho, tipo, permissão, dono, link, sha256 de cada entrada, inclusive
# diretórios vazios) sem os campos time=, mais o .PKGINFO sem data/empacotador/tamanho.
# Retorna ≠ 0 se não conseguir ler o pacote — quem chama precisa tratar.
assinatura_conteudo() {
  local mtree pkginfo
  mtree=$(bsdtar -xOf "$1" .MTREE | gzip -dc) || return 1
  pkginfo=$(bsdtar -xOf "$1" .PKGINFO) || return 1
  [ -n "$mtree" ] && [ -n "$pkginfo" ] || return 1
  printf '%s\n' "$mtree" | grep -vE '^\./\.(PKGINFO|BUILDINFO) ' | sed -E 's/ time=[0-9.]+//'
  printf '%s\n' "$pkginfo" | grep -vE '^(builddate|packager|size) = '
}

[ $# -eq 3 ] || die "uso: build-repo.sh <arquivo-ordem> <raiz-pacotes> <dir-saida>"
ordem=$1
raiz=$2
out=$3

fpr=${XINGUOS_GPG_FPR:-}
[ -n "$fpr" ] || die "XINGUOS_GPG_FPR não definido"
gpg --batch --list-secret-keys "$fpr" >/dev/null 2>&1 || die "chave secreta $fpr não está no keyring"
[ -f "$ordem" ] || die "arquivo de ordem não existe: $ordem"
publicados=${XINGUOS_PUBLICADOS:-}

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
  # Pacote compilado (arch ≠ any, ex.: Calamares) já publicado: o binário nunca sai igual,
  # então não recompila — reaproveita os bytes publicados (o nome é imutável; mudar = subir pkgrel)
  # e instala, para os pacotes seguintes acharem a dependência.
  if [ -n "$publicados" ]; then
    mapfile -t lista < <(cd "$dir" && sudo -u builder makepkg --packagelist </dev/null 2>/dev/null)
    todos=${#lista[@]}
    for pkg in "${lista[@]}"; do
      nome=$(basename "$pkg")
      case "$nome" in *-any.pkg.tar.*) todos=0; break ;; esac
      [ -f "$publicados/$nome" ] && [ -f "$publicados/$nome.sig" ] || { todos=0; break; }
    done
    if [ "$todos" -gt 0 ]; then
      reusar=()
      for pkg in "${lista[@]}"; do
        nome=$(basename "$pkg")
        cp "$publicados/$nome" "$publicados/$nome.sig" "$out/"
        # cópia sem o .sig ao lado: instala como o makepkg -si faz (a assinatura vai para o repo)
        cp "$publicados/$nome" "$trabalho/$nome"
        reusar+=("$trabalho/$nome")
        echo "==> $nome já publicado (compilado): reaproveitado sem recompilar"
      done
      pacman -U --noconfirm --needed "${reusar[@]}" </dev/null || die "não consegui instalar o publicado de $linha"
      rm -f "${reusar[@]}"
      continue
    fi
  fi
  echo "==> compilando $linha"
  # -i instala o resultado, para que os pacotes seguintes encontrem as dependências
  # </dev/null: nada dentro do build pode ler (e engolir) as próximas linhas do arquivo de ordem
  (cd "$dir" && sudo -u builder makepkg -si --noconfirm --cleanbuild </dev/null) || die "makepkg falhou em $linha"
  for pkg in "$dir"/*.pkg.tar.zst; do
    nome=$(basename "$pkg")
    if [ -n "$publicados" ] && [ -f "$publicados/$nome" ] && [ -f "$publicados/$nome.sig" ]; then
      novo=$(assinatura_conteudo "$pkg") || die "não consegui ler o conteúdo de $nome"
      antigo=$(assinatura_conteudo "$publicados/$nome") || die "não consegui ler o conteúdo publicado de $nome"
      if [ "$novo" != "$antigo" ]; then
        die "conteúdo mudou sem subir pkgrel: $nome"
      fi
      echo "==> $nome já publicado: reaproveitando os bytes publicados"
      cp "$publicados/$nome" "$publicados/$nome.sig" "$out/"
      rm -f "$pkg"
    else
      namcap "$pkg" </dev/null || echo "build-repo: aviso: namcap reclamou de $nome" >&2
      mv "$pkg" "$out/"
    fi
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
  [ -f "$pkg.sig" ] && continue  # reaproveitado: já tem a assinatura publicada
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
