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
