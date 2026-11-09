#!/usr/bin/env bash
# PROTÓTIPO DESCARTÁVEL do Marco 0. Uso: sudo ./instalar.sh  (de dentro de marco0/prototipo)
set -euo pipefail

[ "$(id -u)" -eq 0 ] || { echo "rode com sudo" >&2; exit 1; }
aqui=$(cd "$(dirname "$0")" && pwd)

visudo -cf "$aqui/sudoers-xinguos-prototipo"
install -Dm755 "$aqui/steamos-session-select" /usr/local/bin/steamos-session-select
install -Dm755 "$aqui/xinguos-escrever-sessao" /usr/local/lib/xinguos/xinguos-escrever-sessao
install -Dm440 "$aqui/sudoers-xinguos-prototipo" /etc/sudoers.d/xinguos-prototipo
echo "protótipo instalado: teste com  steamos-session-select gamescope"
