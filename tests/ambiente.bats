#!/usr/bin/env bats

@test "multilib habilitado" {
  run pacman -Sl multilib
  [ "$status" -eq 0 ]
}

@test "builder pode usar pacman via sudo" {
  run sudo -u builder sudo -n pacman -V
  [ "$status" -eq 0 ]
}

@test "makepkg disponível" {
  command -v makepkg
}
