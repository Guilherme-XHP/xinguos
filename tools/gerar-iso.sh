#!/usr/bin/env bash
# gerar-iso.sh — pede ao CI do GitHub a ISO de instalação de um branch, espera, baixa e confere.
# Funciona no XInguOS (ou no Windows com Git Bash): só precisa do git e do gh logado (gh auth login).
#
# uso: tools/gerar-iso.sh [branch] [pasta-destino]
#   branch         padrão: o branch atual (precisa estar no GitHub: git push)
#   pasta-destino  padrão: ~/isos
#
# Erro de rede no CI (504/timeout do GitHub) tenta de novo até 3 vezes; erro de verdade para
# e mostra as linhas de erro do log.
set -uo pipefail

cd "$(dirname "$0")/.." || exit 1
branch=${1:-$(git rev-parse --abbrev-ref HEAD)}
destino=${2:-$HOME/isos}
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

command -v gh >/dev/null || { echo "gerar-iso: falta o gh (sudo pacman -S github-cli)" >&2; exit 1; }
gh auth status >/dev/null 2>&1 || { echo "gerar-iso: faça login antes: gh auth login" >&2; exit 1; }

run=""
for tentativa in 1 2 3; do
  antes=$(gh run list --workflow repo.yml --branch "$branch" --event workflow_dispatch --limit 1 --json databaseId --jq '.[0].databaseId // 0')
  gh workflow run repo.yml --ref "$branch" -f iso_instalar=true || exit 1
  novo=$antes
  for _ in $(seq 1 30); do
    sleep 10
    novo=$(gh run list --workflow repo.yml --branch "$branch" --event workflow_dispatch --limit 1 --json databaseId --jq '.[0].databaseId // 0')
    [ "$novo" != "$antes" ] && break
  done
  [ "$novo" != "$antes" ] || { echo "gerar-iso: o GitHub não criou o run" >&2; exit 1; }
  echo "gerar-iso: tentativa $tentativa, run $novo (leva uns 40 min)"
  gh run watch "$novo" --exit-status --interval 60 >/dev/null 2>&1
  gh run view "$novo" --json jobs --jq '.jobs[]|"\(.name)=\(.conclusion)"' | tr '\n' ' '
  echo
  if [ "$(gh run view "$novo" --json conclusion --jq .conclusion)" = success ]; then
    run=$novo
    break
  fi
  gh run view "$novo" --log-failed > "$tmp/falha.log" 2>&1
  if grep -qE "Operation too slow|failed retrieving|Failure while downloading|error: 50[234]|returned error: 50[234]" "$tmp/falha.log"; then
    echo "gerar-iso: rede instável no CI, tentando de novo"
    continue
  fi
  echo "gerar-iso: falhou (não foi rede). Erros:" >&2
  grep -E "##\[error\]|not ok|ERRO|ERROR" "$tmp/falha.log" | tail -20 >&2
  exit 1
done
[ -n "$run" ] || { echo "gerar-iso: 3 tentativas sem sucesso" >&2; exit 1; }

gh run download "$run" -n xinguos-iso -D "$tmp/iso" || exit 1
(cd "$tmp/iso" && sha256sum -c xinguos.iso.sha256) || exit 1
mkdir -p "$destino"
mv -f "$tmp/iso/xinguos.iso" "$tmp/iso/xinguos.iso.sha256" "$destino/"
(cd "$destino" && sha256sum -c xinguos.iso.sha256) || exit 1
echo "gerar-iso: pronto: $destino/xinguos.iso"
