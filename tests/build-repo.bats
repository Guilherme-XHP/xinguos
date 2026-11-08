#!/usr/bin/env bats

setup_file() {
  export GNUPGHOME="$BATS_FILE_TMPDIR/gnupg"
  mkdir -m 700 -p "$GNUPGHOME"
  gpg --batch --passphrase '' --quick-gen-key "Teste <t@t>" ed25519 sign never
  XINGUOS_GPG_FPR=$(gpg --list-secret-keys --with-colons | awk -F: '/^fpr/{print $10; exit}')
  export XINGUOS_GPG_FPR
  export OUT="$BATS_FILE_TMPDIR/out"
}

@test "compila em ordem, inclui split e gera banco real assinado" {
  run tools/build-repo.sh tests/fixtures/ordem-ok.txt tests/fixtures/pacotes "$OUT"
  echo "$output"
  [ "$status" -eq 0 ]
  for p in xg-teste-a xg-teste-b xg-split-um xg-split-dois; do
    ls "$OUT"/$p-1-1-any.pkg.tar.zst
    ls "$OUT"/$p-1-1-any.pkg.tar.zst.sig
  done
  [ -f "$OUT/xinguos.db" ]
  [ ! -L "$OUT/xinguos.db" ]
  [ -f "$OUT/xinguos.db.sig" ]
  [ ! -L "$OUT/xinguos.db.sig" ]
  [ -f "$OUT/xinguos.files" ]
  [ ! -L "$OUT/xinguos.files" ]
  gpg --verify "$OUT/xinguos.db.sig" "$OUT/xinguos.db"
  run tar -tzf "$OUT/xinguos.db"
  [[ "$output" == *xg-split-dois-1-1/* ]]
}

@test "sem chave não publica nada" {
  run env XINGUOS_GPG_FPR= tools/build-repo.sh tests/fixtures/ordem-ok.txt tests/fixtures/pacotes "$BATS_TEST_TMPDIR/o"
  [ "$status" -ne 0 ]
  [[ "$output" == *"XINGUOS_GPG_FPR não definido"* ]]
  [ ! -e "$BATS_TEST_TMPDIR/o/xinguos.db" ]
}

@test "chave inexistente não publica nada" {
  run env XINGUOS_GPG_FPR=0000000000000000000000000000000000000000 tools/build-repo.sh tests/fixtures/ordem-ok.txt tests/fixtures/pacotes "$BATS_TEST_TMPDIR/o"
  [ "$status" -ne 0 ]
  [[ "$output" == *"não está no keyring"* ]]
  [ ! -e "$BATS_TEST_TMPDIR/o/xinguos.db" ]
}

@test "epoch no nome falha com mensagem clara" {
  run tools/build-repo.sh tests/fixtures/ordem-epoch.txt tests/fixtures/pacotes "$BATS_TEST_TMPDIR/o"
  echo "$output"
  [ "$status" -ne 0 ]
  [[ "$output" == *"nome de pacote inválido para GitHub Releases"* ]]
  [ ! -e "$BATS_TEST_TMPDIR/o/xinguos.db" ]
}

@test "build que lê o stdin não engole os pacotes seguintes" {
  run tools/build-repo.sh tests/fixtures/ordem-stdin.txt tests/fixtures/pacotes "$BATS_TEST_TMPDIR/o"
  echo "$output"
  [ "$status" -eq 0 ]
  ls "$BATS_TEST_TMPDIR"/o/xg-teste-a-1-1-any.pkg.tar.zst
}

@test "pacote já publicado é reaproveitado byte a byte (nome é imutável)" {
  local pub="$BATS_TEST_TMPDIR/pub" novo="$BATS_TEST_TMPDIR/novo"
  tools/build-repo.sh tests/fixtures/ordem-ok.txt tests/fixtures/pacotes "$pub"
  sleep 1
  XINGUOS_PUBLICADOS="$pub" run tools/build-repo.sh tests/fixtures/ordem-ok.txt tests/fixtures/pacotes "$novo"
  echo "$output"
  [ "$status" -eq 0 ]
  for p in xg-teste-a xg-teste-b xg-split-um xg-split-dois; do
    cmp "$pub/$p-1-1-any.pkg.tar.zst" "$novo/$p-1-1-any.pkg.tar.zst"
    cmp "$pub/$p-1-1-any.pkg.tar.zst.sig" "$novo/$p-1-1-any.pkg.tar.zst.sig"
  done
  gpg --verify "$novo/xinguos.db.sig" "$novo/xinguos.db"
}
