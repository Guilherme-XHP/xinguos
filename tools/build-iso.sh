#!/usr/bin/env bash
# Monta uma ISO ao vivo do XInguOS a partir do perfil "baseline" do archiso
# mais o overlay em <overlay> (pacotes.txt + airootfs/ [+ calamares/]).
#   iso/teste   → xinguos-teste.iso (Marco 0: protótipos da troca de sessão)
#   iso/instalar → xinguos.iso (com XINGUOS_ISO_NOME=xinguos; instalador Calamares)
#
# uso: build-iso.sh <overlay> <dir-saida> [--so-perfil]
# ambiente: XINGUOS_REPO_URL (obrigatório) — Server do repositório [xinguos]
#           XINGUOS_ISO_NOME (padrão xinguos-teste) — nome da ISO; o rótulo é ele em maiúsculas
#
# Com --so-perfil, só prepara o perfil, imprime o caminho dele na última linha e
# para (usado nos testes). Sem ele, roda o mkarchiso (precisa de root e de --privileged
# no container) e gera <dir-saida>/<nome>.iso + .sha256.
set -euo pipefail

die() { echo "build-iso: $*" >&2; exit 1; }

[ $# -ge 2 ] && [ $# -le 3 ] || die "uso: build-iso.sh <overlay> <dir-saida> [--so-perfil]"
overlay=$1
out=$2
so_perfil=false
[ "${3:-}" = --so-perfil ] && so_perfil=true

url=${XINGUOS_REPO_URL:-}
nome=${XINGUOS_ISO_NOME:-xinguos-teste}
[[ "$nome" =~ ^[a-z0-9-]+$ ]] || die "XINGUOS_ISO_NOME inválido: $nome"
rotulo=$(tr 'a-z-' 'A-Z_' <<<"$nome")
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

# 3. só na ISO de teste: protótipo do Marco 0 (os-session-select é o gancho oficial do
#    gamescope-session-steam) e o criador de persistência
permissoes=()
if [ "$nome" = xinguos-teste ]; then
  proto="$raiz/marco0/prototipo"
  install -Dm755 "$proto/steamos-session-select" "$air/usr/local/bin/steamos-session-select"
  install -Dm755 "$proto/steamos-session-select" "$air/usr/lib/os-session-select"
  install -Dm755 "$proto/xinguos-escrever-sessao" "$air/usr/local/lib/xinguos/xinguos-escrever-sessao"
  install -Dm440 "$proto/sudoers-xinguos-prototipo" "$air/etc/sudoers.d/xinguos-prototipo"
  permissoes+=("/usr/lib/os-session-select:755" "/usr/local/lib/xinguos/xinguos-escrever-sessao:755")
  if [ -f "$raiz/marco0/criar-persistencia.sh" ]; then
    install -Dm755 "$raiz/marco0/criar-persistencia.sh" "$air/usr/local/bin/criar-persistencia"
  fi
fi
# instalador: configuração do Calamares vai para /etc/calamares
if [ -d "$overlay/calamares" ]; then
  mkdir -p "$air/etc/calamares"
  cp -r "$overlay/calamares/." "$air/etc/calamares/"
fi

# 4. serviços (links criados aqui, porque o git no Windows não guarda links simbólicos)
sd="$air/etc/systemd/system"
mkdir -p "$sd/multi-user.target.wants"
ln -sfn /usr/lib/systemd/system/sddm.service "$sd/display-manager.service"
ln -sfn /usr/lib/systemd/system/NetworkManager.service "$sd/multi-user.target.wants/NetworkManager.service"
# todo serviço próprio do overlay é habilitado
for svc in "$overlay"/airootfs/etc/systemd/system/*.service; do
  [ -f "$svc" ] || continue
  ln -sfn "/etc/systemd/system/$(basename "$svc")" "$sd/multi-user.target.wants/$(basename "$svc")"
done

# 5. identidade e permissões da ISO
sed -i -e "s/^iso_name=.*/iso_name=\"$nome\"/" \
       -e "s/^iso_label=.*/iso_label=\"$rotulo\"/" \
       -e 's|^iso_publisher=.*|iso_publisher="XInguOS <https://github.com/Guilherme-XHP/xinguos>"|' \
       "$perfil/profiledef.sh"
# executáveis e sudoers do overlay e do protótipo (o git no Windows não guarda o bit +x)
while IFS= read -r f; do
  permissoes+=("${f#"$air"}:755")
done < <(find "$air/usr/local/bin" "$air/usr/lib/xinguos" -type f 2>/dev/null)
while IFS= read -r f; do
  permissoes+=("${f#"$air"}:440")
done < <(find "$air/etc/sudoers.d" -type f 2>/dev/null)
while IFS= read -r f; do
  permissoes+=("${f#"$air"}:755")
done < <(find "$air/etc/skel/Desktop" -type f -name '*.desktop' 2>/dev/null)
{
  echo "file_permissions+=("
  for item in "${permissoes[@]}"; do
    echo "  [\"${item%:*}\"]=\"0:0:${item##*:}\""
  done
  echo ")"
} >> "$perfil/profiledef.sh"

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
isos=("$out"/"$nome"-*.iso)
[ ${#isos[@]} -eq 1 ] || die "esperava 1 ISO em $out, achei ${#isos[@]}"
mv "${isos[0]}" "$out/$nome.iso"
(cd "$out" && sha256sum "$nome.iso" > "$nome.iso.sha256")
rm -rf "$tmp"
echo "$out/$nome.iso"
