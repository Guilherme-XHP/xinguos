#!/usr/bin/env bats

@test "jobs que publicam ou leem a release não rodam ao mesmo tempo" {
  for job in build smoke iso-teste; do
    awk -v j="  $job:" '$0==j{f=1;next} f&&/^  [a-z-]+:$/{f=0} f' .github/workflows/repo.yml > "$BATS_TEST_TMPDIR/job"
    grep -q 'group: repo-x86_64' "$BATS_TEST_TMPDIR/job"
    grep -q 'cancel-in-progress: false' "$BATS_TEST_TMPDIR/job"
  done
}

@test "instruções nunca fazem atualização parcial (pacman -Sy sem u)" {
  run grep -rnE 'pacman -Sy( |$)' README.md marco0/README.md tools/confiar-xinguos.sh
  echo "$output"
  [ "$status" -ne 0 ]
}
