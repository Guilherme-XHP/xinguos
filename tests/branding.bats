#!/usr/bin/env bats

R=packages/xinguos/xinguos-branding

@test "os-release vira XInguOS (ID_LIKE=arch) e o link do filesystem é trocado por arquivo" {
  local raiz; raiz=$(mktemp -d)
  mkdir -p "$raiz/etc" "$raiz/usr/lib"
  echo 'NAME="Arch Linux"' > "$raiz/usr/lib/os-release"
  ln -s ../usr/lib/os-release "$raiz/etc/os-release"
  run bash "$R/xinguos-os-release" --raiz "$raiz"
  [ "$status" -eq 0 ]
  [ ! -L "$raiz/etc/os-release" ]
  grep -qx 'NAME="XInguOS"' "$raiz/etc/os-release"
  grep -qx 'ID=xinguos' "$raiz/etc/os-release"
  grep -qx 'ID_LIKE=arch' "$raiz/etc/os-release"
  grep -qx 'LOGO=xinguos' "$raiz/etc/os-release"
  # o original do Arch fica intacto
  grep -qx 'NAME="Arch Linux"' "$raiz/usr/lib/os-release"
  # rodar de novo não quebra
  run bash "$R/xinguos-os-release" --raiz "$raiz"
  [ "$status" -eq 0 ]
}

@test "hook do os-release roda depois de atualizar o filesystem e o próprio branding" {
  grep -qx 'Target = filesystem' "$R/xinguos-os-release.hook"
  grep -qx 'Target = xinguos-branding' "$R/xinguos-os-release.hook"
  grep -qx 'When = PostTransaction' "$R/xinguos-os-release.hook"
  grep -qx 'Exec = /usr/lib/xinguos/xinguos-os-release' "$R/xinguos-os-release.hook"
  grep -q 'ln -sf ../usr/lib/os-release' "$R/xinguos-branding.install"
}

@test "logo e wallpaper são SVG válidos; metadata do wallpaper é JSON" {
  for f in "$R/logo/xinguos.svg" "$R/wallpaper/XInguOS/contents/images/1920x1080.svg"; do
    python3 -c 'import sys, xml.dom.minidom as m; d = m.parse(sys.argv[1]); assert d.documentElement.tagName == "svg"' "$f"
  done
  python3 -m json.tool "$R/wallpaper/XInguOS/metadata.json" >/dev/null
  grep -q '"Id": "XInguOS"' "$R/wallpaper/XInguOS/metadata.json"
}

@test "Sobre o sistema, SDDM e caminhos instalados" {
  grep -qx 'LogoPath=/usr/share/pixmaps/xinguos.svg' "$R/kcm-about-distrorc"
  grep -qx 'background=/usr/share/wallpapers/XInguOS/contents/images/1920x1080.svg' "$R/sddm/theme.conf.user"
  grep -qx 'Current=breeze' "$R/sddm/10-xinguos-tema.conf"
  for p in /usr/share/pixmaps/xinguos.svg /usr/share/icons/hicolor/scalable/apps/xinguos.svg \
           /usr/share/wallpapers/XInguOS /etc/xdg/kcm-about-distrorc /usr/share/sddm/themes/breeze/theme.conf.user \
           /etc/sddm.conf.d/10-xinguos-tema.conf /usr/share/libalpm/hooks/xinguos-os-release.hook \
           /usr/lib/xinguos/xinguos-os-release /usr/share/xinguos/easter-egg/cachorro.jpg; do
    grep -q "$p" "$R/PKGBUILD"
  done
}

@test "easter egg: a foto do cachorro é a mesma de branding/" {
  [ "$(sha256sum < "$R/easter-egg/cachorro.jpg")" = "$(sha256sum < branding/easter-egg/cachorro.jpg)" ]
}

@test "boot com a logo XHP: tema do plymouth e do GRUB no vinho" {
  local B=packages/xinguos/xinguos-branding
  grep -qx 'ModuleName=two-step' "$B/plymouth/xinguos.plymouth"
  grep -qx 'ImageDir=/usr/share/plymouth/themes/xinguos' "$B/plymouth/xinguos.plymouth"
  grep -qx 'BackgroundStartColor=0x140707' "$B/plymouth/xinguos.plymouth"
  grep -q 'desktop-image: "background.png"' "$B/grub/theme.txt"
  grep -q 'selected_item_pixmap_style = "select_\*.png"' "$B/grub/theme.txt"
  grep -q 'Unifont Regular 16' "$B/grub/theme.txt"
  run bash -c "source $B/PKGBUILD; printf '%s\n' \"\${depends[@]}\" \"\${makedepends[@]}\""
  grep -qx plymouth <<<"$output"
  grep -qx librsvg <<<"$output"
  grep -q 'ply="$pkgdir/usr/share/plymouth/themes/xinguos"' "$B/PKGBUILD"
  grep -q 'logo/xinguos.svg -o "$ply/watermark.png"' "$B/PKGBUILD"
  grep -q 'grub="$pkgdir/usr/share/grub/themes/xinguos"' "$B/PKGBUILD"
  grep -q 'grub/fundo.svg -o "$grub/background.png"' "$B/PKGBUILD"
  grep -q 'install -Dm644 grub/theme.txt "$grub/theme.txt"' "$B/PKGBUILD"
  # o fundo do GRUB é SVG válido com a logo
  python3 -c 'import sys, xml.dom.minidom as m; m.parse(sys.argv[1])' "$B/grub/fundo.svg"
  grep -q '#640000' "$B/grub/fundo.svg"
}
