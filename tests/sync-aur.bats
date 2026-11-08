#!/usr/bin/env bats

setup() {
  local trabalho="$BATS_TEST_TMPDIR/trabalho"
  git init -q "$trabalho"
  echo "pkgname=pkg-falso" > "$trabalho/PKGBUILD"
  echo "patch" > "$trabalho/extra.patch"
  git -C "$trabalho" add -A
  git -C "$trabalho" -c user.name=t -c user.email=t@t commit -qm inicial
  mkdir -p "$BATS_TEST_TMPDIR/aur"
  git clone -q --bare "$trabalho" "$BATS_TEST_TMPDIR/aur/pkg-falso.git"
  export AUR_GIT_BASE="file://$BATS_TEST_TMPDIR/aur"
  R="$BATS_TEST_TMPDIR/raiz"
}

@test "copia os arquivos sem .git e grava o commit" {
  run tools/sync-aur.sh pkg-falso "$R"
  echo "$output"
  [ "$status" -eq 0 ]
  [ -f "$R/aur/pkg-falso/PKGBUILD" ]
  [ -f "$R/aur/pkg-falso/extra.patch" ]
  [ ! -e "$R/aur/pkg-falso/.git" ]
  [ "$(cat "$R/aur/pkg-falso/.aur-commit")" = "$(git -C "$BATS_TEST_TMPDIR/aur/pkg-falso.git" rev-parse HEAD)" ]
}

@test "pkgbase inexistente não apaga a cópia atual" {
  mkdir -p "$R/aur/nao-existe"
  echo velho > "$R/aur/nao-existe/PKGBUILD"
  run tools/sync-aur.sh nao-existe "$R"
  echo "$output"
  [ "$status" -ne 0 ]
  [[ "$output" == *"sync-aur:"* ]]
  [ "$(cat "$R/aur/nao-existe/PKGBUILD")" = velho ]
}

@test "não copia o .gitignore do AUR (ele esconderia arquivos do git)" {
  local trabalho="$BATS_TEST_TMPDIR/trabalho2"
  git init -q "$trabalho"
  printf '*
!PKGBUILD
!.gitignore
' > "$trabalho/.gitignore"
  echo "pkgname=pkg-ign" > "$trabalho/PKGBUILD"
  echo "post_install() { :; }" > "$trabalho/pkg-ign.install"
  git -C "$trabalho" add -f -A
  git -C "$trabalho" -c user.name=t -c user.email=t@t commit -qm inicial
  git clone -q --bare "$trabalho" "$BATS_TEST_TMPDIR/aur/pkg-ign.git"
  run tools/sync-aur.sh pkg-ign "$R"
  [ "$status" -eq 0 ]
  [ -f "$R/aur/pkg-ign/pkg-ign.install" ]
  [ ! -e "$R/aur/pkg-ign/.gitignore" ]
}

@test "pacote -git com pin tem o commit fixado na source" {
  local trabalho="$BATS_TEST_TMPDIR/trabalho3"
  git init -q "$trabalho"
  printf 'pkgname=pkg-pin\nsource=("x::git+https://exemplo.invalid/x.git")\n' > "$trabalho/PKGBUILD"
  git -C "$trabalho" add -A
  git -C "$trabalho" -c user.name=t -c user.email=t@t commit -qm inicial
  git clone -q --bare "$trabalho" "$BATS_TEST_TMPDIR/aur/pkg-pin.git"
  mkdir -p "$R"
  echo "pkg-pin 0123456789abcdef0123456789abcdef01234567" > "$R/aur-pins.txt"
  run tools/sync-aur.sh pkg-pin "$R"
  echo "$output"
  [ "$status" -eq 0 ]
  grep -qF 'git+https://exemplo.invalid/x.git#commit=0123456789abcdef0123456789abcdef01234567"' "$R/aur/pkg-pin/PKGBUILD"
}

@test "pin sem source git+ falha em vez de ignorar" {
  mkdir -p "$R"
  echo "pkg-falso 0123456789abcdef0123456789abcdef01234567" > "$R/aur-pins.txt"
  run tools/sync-aur.sh pkg-falso "$R"
  [ "$status" -ne 0 ]
  [[ "$output" == *"pin"* ]]
}
