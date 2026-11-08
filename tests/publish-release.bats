#!/usr/bin/env bats

setup() {
  export PATH="$BATS_TEST_DIRNAME/stubs:$PATH"
  export GH_LOG="$BATS_TEST_TMPDIR/gh.log"
  : > "$GH_LOG"
  D="$BATS_TEST_TMPDIR/d"
  mkdir -p "$D"
  for f in foo-1-1-any.pkg.tar.zst foo-1-1-any.pkg.tar.zst.sig xinguos.gpg \
           xinguos.db xinguos.db.sig xinguos.files xinguos.files.sig; do
    touch "$D/$f"
  done
}

@test "cria a release quando não existe" {
  GH_RELEASE_EXISTE=1 run tools/publish-release.sh "$D" repo-x86_64
  [ "$status" -eq 0 ]
  grep -q '^release create repo-x86_64' "$GH_LOG"
}

@test "banco sobe depois de todos os pacotes" {
  GH_RELEASE_EXISTE=0 run tools/publish-release.sh "$D" repo-x86_64
  [ "$status" -eq 0 ]
  ultimo_pkg=$(grep -n 'upload.*pkg\.tar\.zst' "$GH_LOG" | tail -1 | cut -d: -f1)
  primeiro_db=$(grep -n 'upload.*xinguos\.\(db\|files\)' "$GH_LOG" | head -1 | cut -d: -f1)
  [ -n "$ultimo_pkg" ]
  [ -n "$primeiro_db" ]
  [ "$ultimo_pkg" -lt "$primeiro_db" ]
}

@test "apaga asset antigo e mantém os atuais" {
  GH_RELEASE_EXISTE=0 GH_ASSETS_EXISTENTES=$'foo-0.9-1-any.pkg.tar.zst\nxinguos.db\nxinguos.gpg' run tools/publish-release.sh "$D" repo-x86_64
  [ "$status" -eq 0 ]
  grep -q '^release delete-asset repo-x86_64 foo-0.9-1-any.pkg.tar.zst -y' "$GH_LOG"
  run grep -q 'delete-asset repo-x86_64 xinguos.db ' "$GH_LOG"
  [ "$status" -ne 0 ]
  run grep -q 'delete-asset repo-x86_64 xinguos.gpg ' "$GH_LOG"
  [ "$status" -ne 0 ]
}
