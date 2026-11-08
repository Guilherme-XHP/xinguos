#!/usr/bin/env bash
# Monta a ISO ao vivo de teste do XInguOS a partir do perfil "baseline" do archiso
# mais o overlay em <overlay> (pacotes.txt + airootfs/).
#
# uso: build-iso.sh <overlay> <dir-saida> [--so-perfil]
# ambiente: XINGUOS_REPO_URL (obrigatório) — Server do repositório [xinguos]
#
# Com --so-perfil, só prepara o perfil, imprime o caminho dele na última linha e
# para (usado nos testes). Sem ele, roda o mkarchiso (precisa de root e de --privileged
# no container) e gera <dir-saida>/xinguos-teste.iso + .sha256.
set -euo pipefail

die() { echo "build-iso: $*" >&2; exit 1; }

[ $# -ge 2 ] && [ $# -le 3 ] || die "uso: build-iso.sh <overlay> <dir-saida> [--so-perfil]"
overlay=$1
out=$2
so_perfil=false
[ "${3:-}" = --so-perfil ] && so_perfil=true

url=${XINGUOS_REPO_URL:-}
[ -n "$url" ] || die "XINGUOS_REPO_URL não definido"
[ -f "$overlay/pacotes.txt" ] || die "falta $overlay/pacotes.txt"
baseline=/usr/share/archiso/configs/baseline
[ -d "$baseline" ] || die "archiso não instalado ($baseline não existe)"

raiz=$(cd "$(dirname "$0")/.." && pwd)
tmp=$(mktemp -d)
perfil="$tmp/perfil"
cp -r "$baseline" "$perfil"
air="$perfil/airootfs"

# 1. pacotes e arquivos do overlay
cat "$overlay/pacotes.txt" >> "$perfil/packages.x86_64"
cp -r "$overlay/airootfs/." "$air/"

# 2. repositórios: multilib + [xinguos], no build e no sistema ao vivo
if ! grep -q '^\[multilib\]' "$perfil/pacman.conf"; then
  printf '\n[multilib]\nInclude = /etc/pacman.d/mirrorlist\n' >> "$perfil/pacman.conf"
fi
printf '\n[xinguos]\nSigLevel = Required DatabaseOptional\nServer = %s\n' "$url" >> "$perfil/pacman.conf"
install -Dm644 "$perfil/pacman.conf" "$air/etc/pacman.conf"

# 3. protótipo do Marco 0 (os.session-select é o gancho oficial do gamescope-session-steam)
proto="$raiz/marco0/prototipo"
install -Dm755 "$proto/steamos-session-select" "$air/usr/local/bin/steamos-session-select"
install -Dm755 "$proto/steamos-session-select" "$air/usr/lib/os-session-select"
install -Dm755 "$proto/xinguos-escrever-sessao" "$air/usr/local/lib/xinguos/xinguos-escrever-sessao"
install -Dm440 "$proto/sudoers-xinguos-prototipo" "$air/etc/sudoers.d/xinguos-prototipo"
if [ -f "$raiz/marco0/criar-persistencia.sh" ]; then
  install -Dm755 "$raiz/marco0/criar-persistencia.sh" "$air/usr/local/bin/criar-persistencia"
fi

# 4. serviços (links criados aqui, porque o git no Windows não guarda links simbólicos)
sd="$air/etc/systemd/system"
mkdir -p "$sd/multi-user.target.wants"
ln -sfn /usr/lib/systemd/system/sddm.service "$sd/display-manager.service"
ln -sfn /usr/lib/systemd/system/NetworkManager.service "$sd/multi-user.target.wants/NetworkManager.service"
ln -sfn /etc/systemd/system/xinguos-teste-usuario.service "$sd/multi-user.target.wants/xinguos-teste-usuario.service"

# 5. identidade e permissões da ISO
sed -i -e 's/^iso_name=.*/iso_name="xinguos-teste"/' \
       -e 's/^iso_label=.*/iso_label="XINGUOS_TESTE"/' \
       -e 's|^iso_publisher=.*|iso_publisher="XInguOS <https://github.com/Guilherme-XHP/xinguos>"|' \
       "$perfil/profiledef.sh"
cat >> "$perfil/profiledef.sh" <<'EOF'
file_permissions+=(
  ["/usr/local/bin/steamos-session-select"]="0:0:755"
  ["/usr/lib/os-session-select"]="0:0:755"
  ["/usr/local/lib/xinguos/xinguos-escrever-sessao"]="0:0:755"
  ["/usr/local/bin/xinguos-teste-usuario"]="0:0:755"
  ["/usr/local/bin/criar-persistencia"]="0:0:755"
  ["/etc/sudoers.d/xinguos-prototipo"]="0:0:440"
  ["/etc/sudoers.d/10-xinguos-teste"]="0:0:440"
)
EOF

# 6. sem persistência, o tmpfs padrão (256M) não aguenta nem o Steam
for f in "$perfil"/grub/*.cfg "$perfil"/syslinux/*.cfg "$perfil"/efiboot/loader/entries/*.conf; do
  [ -f "$f" ] && sed -i '/archisobasedir=/ s/$/ cow_spacesize=8G/' "$f"
done

if $so_perfil; then
  echo "$perfil"
  exit 0
fi

mkdir -p "$out"
mkarchiso -v -w "$tmp/work" -o "$out" "$perfil"
shopt -s nullglob
isos=("$out"/xinguos-teste-*.iso)
[ ${#isos[@]} -eq 1 ] || die "esperava 1 ISO em $out, achei ${#isos[@]}"
mv "${isos[0]}" "$out/xinguos-teste.iso"
(cd "$out" && sha256sum xinguos-teste.iso > xinguos-teste.iso.sha256)
rm -rf "$tmp"
echo "$out/xinguos-teste.iso"
