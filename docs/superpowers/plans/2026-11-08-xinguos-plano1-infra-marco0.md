# XInguOS — Plano 1: Infra do repositório `[xinguos]` + Marco 0

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Objetivo:** colocar no ar o repositório pacman `[xinguos]`, assinado e publicado pelo GitHub Actions, já com o driver NVIDIA 580xx da GTX 1060. Depois, usá-lo no Marco 0 para testar a viabilidade no PC real do Xingu.

**Arquitetura:**
- Monorepo no GitHub.
- Scripts bash em `tools/`, testados com bats dentro de um container `archlinux` no CI.
- Os PKGBUILDs do AUR ficam copiados em `packages/aur/` e são compilados em ordem fixa. O resultado é assinado com a chave GPG do XInguOS e publicado como assets de uma GitHub Release com a tag `repo-x86_64`.
- O Marco 0 roda num Arch instalado pelo `archinstall` no PC do Xingu, consumindo esse repositório.

**Stack:** bash, bats-core, shellcheck, makepkg/repo-add/namcap, GnuPG, GitHub Actions (container `archlinux:latest`), GitHub CLI (`gh`).

**Spec:** `docs/superpowers/specs/2026-11-08-xinguos-design.md` (seções 2, 3, 10.1, 11 e 12)

**Desvio de ordem em relação à seção 11 do spec:** a infra (etapa 2) vem **antes** do Marco 0 (etapa 1). Motivos:
1. O Marco 0 exige formatar o PC Windows onde este repositório está hoje, então o repositório precisa estar no GitHub antes disso.
2. O Marco 0 instala o driver 580xx a partir do próprio `[xinguos]`, o que testa o repositório de ponta a ponta no hardware real.

O resultado do Marco 0 não muda nada da infra.

**Ambiente local:** o PC é Windows 10 sem WSL e sem Docker, e o `gh` ainda não está instalado. **Nada de Linux roda localmente.** Todo teste de script roda no CI. O executor edita no Windows, faz push e confere o resultado do workflow.

## Restrições globais

- Arch Linux puro e x86-64 genérico. Nada de pacotes v3/v4 nem de repositórios do CachyOS.
- Nome do repositório pacman: `xinguos`. Tag da release: `repo-x86_64`. URL do servidor: `https://github.com/<login>/xinguos/releases/download/repo-x86_64`, onde `<login>` vem de `gh api user -q .login`.
- Configuração para o usuário final: `SigLevel = Required DatabaseOptional`. O banco e todos os pacotes são assinados.
- Os PKGBUILDs do AUR ficam copiados em `packages/aur/<pkgbase>/` com o arquivo `.aur-commit`. O usuário final **nunca** precisa do AUR.
- Os pacotes do driver da GTX 1060 vêm do pkgbase `nvidia-580xx-utils`, que gera `nvidia-580xx-utils`, `nvidia-580xx-dkms` e outros, e do pkgbase `lib32-nvidia-580xx-utils`. Versão atual: 580.196.07.
- Todo script bash começa com `#!/usr/bin/env bash` e `set -euo pipefail` e passa no `shellcheck` sem avisos.
- Quebra de linha LF em tudo (`.gitattributes` já existe).
- Commits em português, terminando com `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- Os passos marcados **[MANUAL — Xingu]** são feitos pelo Xingu: login, chave, instalação do Arch e testes no hardware. O executor prepara tudo e espera.

## Foco da revisão

1. **Upload interrompido no meio:** o banco não pode apontar para um pacote que ainda não subiu. O `publish-release.sh` sobe os pacotes e as `.sig` primeiro e o `xinguos.db`/`xinguos.files` por último (teste na Task 4).
2. **Versão nova deixando lixo:** quando um pacote atualiza, o arquivo antigo some da release (teste na Task 4).
3. **pkgbase com vários pacotes (split):** o `nvidia-580xx-utils` gera vários pacotes, e todos precisam entrar no banco (teste na Task 3).
4. **Chave ausente no CI:** sem `XINGUOS_GPG_FPR`, ou com a chave fora do keyring, a compilação falha e não sai banco nenhum. Nunca se publica nada sem assinatura (teste na Task 3).
5. **Nome de arquivo que o GitHub altera:** pacote com epoch (`:`) ou `+` no nome viraria 404 no pacman. O `build-repo.sh` falha com mensagem clara (teste na Task 3).

---

### Task 1: Esqueleto do repositório e publicação no GitHub

**Arquivos:**
- Criar: `README.md`, `.gitignore`, `packages/ordem.txt` (vazio por enquanto)

**Interfaces:**
- Produz: o remote `origin` em `https://github.com/<login>/xinguos` (**público**, porque o pacman baixa os assets da release sem autenticação).

- [ ] **Passo 1: [MANUAL — Xingu] instalar e logar no GitHub CLI**

Rode no PowerShell:
```
winget install --id GitHub.cli -e
gh auth login
```
Escolha GitHub.com, HTTPS e login pelo navegador.
Para conferir: `gh auth status` mostra `Logged in to github.com account <login>`.

- [ ] **Passo 2: escrever o `README.md`**

Conteúdo:
- uma linha sobre o que é o XInguOS e um link para o spec;
- a seção "Usar o repositório num Arch puro", com o fingerprint da chave (preenchido na Task 5) e esta sequência de comandos: `curl -o /tmp/xinguos.gpg <servidor>/xinguos.gpg` → `pacman-key --add /tmp/xinguos.gpg` → `pacman-key --lsign-key <FPR>` → o bloco de `pacman.conf` abaixo → `pacman -Sy xinguos-keyring`.

```
[xinguos]
SigLevel = Required DatabaseOptional
Server = https://github.com/<login>/xinguos/releases/download/repo-x86_64
```

O `.gitignore` contém `out/`, `*.pkg.tar.zst`, `*.asc` e `privada*`.

- [ ] **Passo 3: criar o repositório público e fazer push**

Rode: `gh repo create xinguos --public --source . --push --description "XInguOS — distro pessoal baseada em Arch"`.
Para conferir: `git remote -v` mostra o `origin`, e `gh repo view --web` abre o repositório com os 2 commits do spec.

- [ ] **Passo 4: commit**

```bash
git add README.md .gitignore packages/ordem.txt
git commit -m "chore: esqueleto do repositório do XInguOS"
git push
```

---

### Task 2: Ambiente de CI e job de testes

**Arquivos:**
- Criar: `tools/ci-setup.sh`, `.github/workflows/repo.yml` (por enquanto só o job `testes`), `tests/ambiente.bats`

**Interfaces:**
- Produz `tools/ci-setup.sh`, rodado como root num `archlinux:latest`. Ele:
  - habilita `[multilib]` no `/etc/pacman.conf`;
  - roda `pacman -Syu --noconfirm base-devel git namcap bats shellcheck github-cli`;
  - cria o usuário `builder` com `NOPASSWD: /usr/bin/pacman` em `/etc/sudoers.d/builder`.
- Produz o job `testes` do workflow `repo.yml`: roda `ci-setup.sh`, depois `shellcheck tools/*.sh`, depois `bats tests/`.
- Gatilhos do workflow: `push` em `main` e `workflow_dispatch`.

- [ ] **Passo 1: escrever o teste `tests/ambiente.bats`**

```bash
@test "multilib habilitado" { run pacman -Sl multilib; [ "$status" -eq 0 ]; }
@test "builder pode usar pacman via sudo" { run sudo -u builder sudo -n pacman -V; [ "$status" -eq 0 ]; }
@test "makepkg disponível" { command -v makepkg; }
```

- [ ] **Passo 2: criar o `repo.yml` com o job `testes` e fazer push sem o `ci-setup.sh`**

O job usa `container: archlinux:latest`, `actions/checkout@v4` e os passos acima.
Rode: `git push`, depois `gh run watch`.
Esperado: **FALHA** em `tools/ci-setup.sh: No such file`.

- [ ] **Passo 3: implementar o `tools/ci-setup.sh`**

Para habilitar o multilib, descomente o bloco `[multilib]` com `sed`. Antes de criar o usuário `builder`, confira se ele já existe (o script tem que poder rodar duas vezes).

- [ ] **Passo 4: push e verificação**

Rode: `git push`, depois `gh run watch`.
Esperado: o job `testes` fica verde, com 3 testes passando e o shellcheck sem avisos.

- [ ] **Passo 5: commit** (antes do push do Passo 4)

```bash
git add tools/ci-setup.sh .github/workflows/repo.yml tests/ambiente.bats
git commit -m "ci: ambiente Arch com bats e shellcheck"
```

---

### Task 3: `tools/build-repo.sh` — compilar, assinar e montar o banco

**Arquivos:**
- Criar: `tools/build-repo.sh`, `tests/build-repo.bats`
- Criar os fixtures em `tests/fixtures/pacotes/`:
  - `xg-teste-a/PKGBUILD`: pacote `any` vazio;
  - `xg-teste-b/PKGBUILD`: `depends=(xg-teste-a)`;
  - `xg-teste-split/PKGBUILD`: `pkgname=(xg-split-um xg-split-dois)`;
  - `xg-teste-epoch/PKGBUILD`: `epoch=1`.
- Criar `tests/fixtures/ordem-ok.txt`, com as linhas `xg-teste-a`, `xg-teste-b` e `xg-teste-split`, e `tests/fixtures/ordem-epoch.txt`, com `xg-teste-epoch`.

**Interfaces:**
- Produz: `tools/build-repo.sh <arquivo-ordem> <raiz-pacotes> <dir-saida>`, rodado como root depois do `ci-setup.sh`.
  - Lê `XINGUOS_GPG_FPR` do ambiente (obrigatório).
  - O arquivo de ordem tem um diretório por linha, relativo a `<raiz-pacotes>`. Linhas vazias e linhas começando com `#` são ignoradas.
  - Para cada diretório: copia para um diretório temporário de propriedade do `builder`, roda `sudo -u builder makepkg -si --noconfirm --cleanbuild` (o `-i` instala, para que os pacotes seguintes encontrem as dependências), roda `namcap` no pacote (o erro só é avisado, não para o build) e move **todos** os `*.pkg.tar.zst` gerados para `<dir-saida>`.
  - No fim, para cada pacote: `gpg --batch --yes --detach-sign -u "$XINGUOS_GPG_FPR"`. Depois: `repo-add --sign --key "$XINGUOS_GPG_FPR" <dir-saida>/xinguos.db.tar.gz <pacotes>`.
  - Por último, troca os links simbólicos `xinguos.db`, `xinguos.files` e as `.sig` por **cópias reais**.
  - Sai com código ≠ 0, sem criar `xinguos.db`, se: o FPR não estiver definido ou não existir no `gpg --list-secret-keys`; algum makepkg falhar; ou algum nome de arquivo tiver caractere fora de `[A-Za-z0-9._-]`. Nesse último caso a mensagem é `nome de pacote inválido para GitHub Releases: <arquivo>`.

- [ ] **Passo 1: escrever os testes `tests/build-repo.bats`**

O `setup_file` gera uma chave descartável:
```
gpg --batch --passphrase '' --quick-gen-key "Teste <t@t>" ed25519 sign never
```
Ele exporta `XINGUOS_GPG_FPR` com o fingerprint da chave e usa `OUT="$BATS_FILE_TMPDIR/out"`.

```bash
@test "compila em ordem, inclui split e gera banco real assinado" {
  run tools/build-repo.sh tests/fixtures/ordem-ok.txt tests/fixtures/pacotes "$OUT"
  [ "$status" -eq 0 ]
  for p in xg-teste-a xg-teste-b xg-split-um xg-split-dois; do
    ls "$OUT"/$p-*.pkg.tar.zst && ls "$OUT"/$p-*.pkg.tar.zst.sig
  done
  [ -f "$OUT/xinguos.db" ] && [ ! -L "$OUT/xinguos.db" ]
  [ -f "$OUT/xinguos.db.sig" ] && [ -f "$OUT/xinguos.files" ] && [ ! -L "$OUT/xinguos.files" ]
  run tar -tzf "$OUT/xinguos.db"; [[ "$output" == *xg-split-dois-* ]]
  gpg --verify "$OUT/xinguos.db.sig" "$OUT/xinguos.db"
}
@test "sem chave não publica nada" {
  XINGUOS_GPG_FPR= run tools/build-repo.sh tests/fixtures/ordem-ok.txt tests/fixtures/pacotes "$BATS_TEST_TMPDIR/o"
  [ "$status" -ne 0 ]; [ ! -e "$BATS_TEST_TMPDIR/o/xinguos.db" ]
}
@test "chave inexistente não publica nada" {
  XINGUOS_GPG_FPR=0000000000000000000000000000000000000000 run tools/build-repo.sh tests/fixtures/ordem-ok.txt tests/fixtures/pacotes "$BATS_TEST_TMPDIR/o"
  [ "$status" -ne 0 ]; [ ! -e "$BATS_TEST_TMPDIR/o/xinguos.db" ]
}
@test "epoch no nome falha com mensagem clara" {
  run tools/build-repo.sh tests/fixtures/ordem-epoch.txt tests/fixtures/pacotes "$BATS_TEST_TMPDIR/o"
  [ "$status" -ne 0 ]; [[ "$output" == *"nome de pacote inválido para GitHub Releases"* ]]
  [ ! -e "$BATS_TEST_TMPDIR/o/xinguos.db" ]
}
```

- [ ] **Passo 2: push sem o script**

Esperado: o job `testes` **FALHA** nos 4 testes (`build-repo.sh: No such file`).

- [ ] **Passo 3: implementar o `tools/build-repo.sh` conforme a interface acima**

Valide o nome dos arquivos **antes** de assinar e de rodar o `repo-add`, para que um nome inválido nunca gere banco.

- [ ] **Passo 4: push e verificação**

Esperado: `testes` verde, com 4 testes novos passando.

- [ ] **Passo 5: commit**

```bash
git add tools/build-repo.sh tests/build-repo.bats tests/fixtures
git commit -m "feat(repo): build-repo compila, assina e monta o banco [xinguos]"
```

---

### Task 4: `tools/publish-release.sh` — publicar na GitHub Release

**Arquivos:**
- Criar: `tools/publish-release.sh`, `tests/publish-release.bats`, `tests/stubs/gh` (stub executável)

**Interfaces:**
- Consome: o `<dir-saida>` gerado pela Task 3.
- Produz: `tools/publish-release.sh <dir-saida> <tag>`, que usa o `gh` com `GH_TOKEN` e `GH_REPO` do ambiente.
  1. Se `gh release view <tag>` falhar, roda `gh release create <tag> --title "Repositório pacman [xinguos]" --notes "Repositório pacman do XInguOS. Não baixe à mão: veja o README." --latest=false`.
  2. Sobe todos os `*.pkg.tar.zst`, `*.pkg.tar.zst.sig` e o `xinguos.gpg` (se existir) com `gh release upload <tag> --clobber`.
  3. **Só depois**, sobe `xinguos.db`, `xinguos.db.sig`, `xinguos.files` e `xinguos.files.sig`.
  4. Lista os assets com `gh release view <tag> --json assets -q '.assets[].name'` e roda `gh release delete-asset <tag> <nome> -y` para cada asset que não está no `<dir-saida>`.

- [ ] **Passo 1: escrever o stub e os testes**

O `tests/stubs/gh` grava cada chamada (`"$*"`) numa linha de `$GH_LOG`. Quando a chamada é `release view <tag> --json ...`, ele imprime o conteúdo de `$GH_ASSETS_EXISTENTES`. Quando é `release view <tag>` sem `--json`, sai com `$GH_RELEASE_EXISTE` (0 ou 1).

O `setup` coloca `tests/stubs` no início do `PATH` e cria em `$D` os arquivos `foo-1-1-any.pkg.tar.zst`, `foo-1-1-any.pkg.tar.zst.sig`, `xinguos.gpg`, `xinguos.db`, `xinguos.db.sig`, `xinguos.files` e `xinguos.files.sig`.

```bash
@test "cria a release quando não existe" {
  GH_RELEASE_EXISTE=1 run tools/publish-release.sh "$D" repo-x86_64
  [ "$status" -eq 0 ]; grep -q '^release create repo-x86_64' "$GH_LOG"
}
@test "banco sobe depois de todos os pacotes" {
  GH_RELEASE_EXISTE=0 run tools/publish-release.sh "$D" repo-x86_64
  ultimo_pkg=$(grep -n 'upload.*pkg.tar.zst' "$GH_LOG" | tail -1 | cut -d: -f1)
  primeiro_db=$(grep -n 'upload.*xinguos\.\(db\|files\)' "$GH_LOG" | head -1 | cut -d: -f1)
  [ "$ultimo_pkg" -lt "$primeiro_db" ]
}
@test "apaga asset antigo e mantém os atuais" {
  GH_RELEASE_EXISTE=0 GH_ASSETS_EXISTENTES=$'foo-0.9-1-any.pkg.tar.zst\nxinguos.db\nxinguos.gpg' run tools/publish-release.sh "$D" repo-x86_64
  grep -q '^release delete-asset repo-x86_64 foo-0.9-1-any.pkg.tar.zst -y' "$GH_LOG"
  ! grep -q 'delete-asset repo-x86_64 xinguos.db ' "$GH_LOG"
  ! grep -q 'delete-asset repo-x86_64 xinguos.gpg ' "$GH_LOG"
}
```

- [ ] **Passo 2: push sem o script.** Esperado: os 3 testes **FALHAM**.

- [ ] **Passo 3: implementar o `tools/publish-release.sh` conforme a interface acima**

- [ ] **Passo 4: push e verificação.** Esperado: `testes` verde.

- [ ] **Passo 5: commit**

```bash
git add tools/publish-release.sh tests/publish-release.bats tests/stubs/gh
git commit -m "feat(repo): publish-release sobe pacotes antes do banco e limpa assets antigos"
```

---

### Task 5: Chave GPG do XInguOS e pacote `xinguos-keyring`

**Arquivos:**
- Criar: `packages/xinguos/xinguos-keyring/PKGBUILD`, `xinguos-keyring.install`, `xinguos.gpg`, `xinguos-trusted`, `xinguos-revoked`
- Modificar: `packages/ordem.txt` (primeira linha: `xinguos/xinguos-keyring`)

**Interfaces:**
- Produz: o secret `XINGUOS_GPG_KEY` no GitHub (chave privada em ASCII armor) e o pacote `xinguos-keyring` (`arch=(any)`, `pkgver=20261108`). Ele instala os 3 arquivos em `/usr/share/pacman/keyrings/` e, no `post_install`/`post_upgrade`, roda `pacman-key --populate xinguos`.
- O fingerprint da chave (40 caracteres hexadecimais) é usado nas Tasks 7 e 9 como `XINGUOS_GPG_FPR`.

- [ ] **Passo 1: [MANUAL — Xingu] gerar a chave no Git Bash**

```bash
gpg --batch --passphrase '' --quick-gen-key "XInguOS Repo <guilhermecaetanno87123@gmail.com>" ed25519 sign never
FPR=$(gpg --list-secret-keys --with-colons "XInguOS Repo" | awk -F: '/^fpr/{print $10; exit}'); echo "$FPR"
gpg --armor --export-secret-keys "$FPR" > privada-xinguos.asc
gh secret set XINGUOS_GPG_KEY < privada-xinguos.asc
gh variable set XINGUOS_GPG_FPR --body "$FPR"
```

A chave fica **sem senha** porque o CI precisa assinar sozinho. A proteção dela é o secret do GitHub.

**Copie o `privada-xinguos.asc` para `D:\Guilherme\xinguos-chave\`** (o HD dos backups) **e para mais um lugar fora do PC** (outro pendrive ou a nuvem, num arquivo compactado com senha). Se essa chave for perdida, todo usuário do repositório precisa confiar numa chave nova. Depois apague a cópia que está dentro da pasta do repositório.

Para conferir: `gh secret list` mostra `XINGUOS_GPG_KEY`.

- [ ] **Passo 2: exportar a parte pública para o pacote**

```bash
gpg --export "$FPR" > packages/xinguos/xinguos-keyring/xinguos.gpg
echo "$FPR:4:" > packages/xinguos/xinguos-keyring/xinguos-trusted
: > packages/xinguos/xinguos-keyring/xinguos-revoked
```

- [ ] **Passo 3: escrever o `PKGBUILD` e o `.install` conforme a interface**

O `package()` usa `install -Dm644` para os três arquivos.

- [ ] **Passo 4: commit** (o pacote é compilado e testado de ponta a ponta na Task 7)

```bash
git add packages/xinguos/xinguos-keyring packages/ordem.txt
git commit -m "feat(keyring): chave de assinatura do repositório [xinguos]"
```

---

### Task 6: `tools/sync-aur.sh` e o driver 580xx copiado no repositório

**Arquivos:**
- Criar: `tools/sync-aur.sh`, `tests/sync-aur.bats`
- Criar (gerados pelo script): `packages/aur/nvidia-580xx-utils/`, `packages/aur/lib32-nvidia-580xx-utils/`
- Modificar: `packages/ordem.txt` (acrescentar `aur/nvidia-580xx-utils` e `aur/lib32-nvidia-580xx-utils`, nessa ordem)

**Interfaces:**
- Produz: `tools/sync-aur.sh <pkgbase> [raiz-pacotes]`, com padrão `packages`.
  - Clona `${AUR_GIT_BASE:-https://aur.archlinux.org}/<pkgbase>.git` num diretório temporário.
  - Substitui `<raiz>/aur/<pkgbase>/` pelo conteúdo do clone, sem `.git`.
  - Grava o hash do `HEAD` em `<raiz>/aur/<pkgbase>/.aur-commit`.
  - Sai com código ≠ 0 e **sem mexer** no diretório existente se o clone falhar ou vier vazio (sem `PKGBUILD`).

- [ ] **Passo 1: escrever os testes**

O `setup` cria um "AUR falso" em `$BATS_TEST_TMPDIR/aur/pkg-falso.git`: um repositório bare com um commit contendo `PKGBUILD` e `extra.patch`. Ele exporta `AUR_GIT_BASE="file://$BATS_TEST_TMPDIR/aur"` e define `R="$BATS_TEST_TMPDIR/raiz"`.

```bash
@test "copia os arquivos sem .git e grava o commit" {
  run tools/sync-aur.sh pkg-falso "$R"; [ "$status" -eq 0 ]
  [ -f "$R/aur/pkg-falso/PKGBUILD" ] && [ -f "$R/aur/pkg-falso/extra.patch" ] && [ ! -e "$R/aur/pkg-falso/.git" ]
  [ "$(cat "$R/aur/pkg-falso/.aur-commit")" = "$(git -C "$BATS_TEST_TMPDIR/aur/pkg-falso.git" rev-parse HEAD)" ]
}
@test "pkgbase inexistente não apaga a cópia atual" {
  mkdir -p "$R/aur/nao-existe"; echo velho > "$R/aur/nao-existe/PKGBUILD"
  run tools/sync-aur.sh nao-existe "$R"; [ "$status" -ne 0 ]
  [ "$(cat "$R/aur/nao-existe/PKGBUILD")" = velho ]
}
```

- [ ] **Passo 2: push sem o script.** Esperado: os 2 testes **FALHAM**.

- [ ] **Passo 3: implementar o `tools/sync-aur.sh`.** Depois do push, esperado: `testes` verde.

- [ ] **Passo 4: copiar o driver** (roda no Git Bash do Windows mesmo, porque só precisa do git)

```bash
tools/sync-aur.sh nvidia-580xx-utils
tools/sync-aur.sh lib32-nvidia-580xx-utils
grep -E '^(pkgname|pkgver)' packages/aur/nvidia-580xx-utils/PKGBUILD
```

Esperado: o `pkgname` lista `nvidia-580xx-utils` e `nvidia-580xx-dkms`, e o `pkgver=580.196.07` (ou mais novo).

**Leia os dois PKGBUILDs inteiros** antes do commit. Eles são código de terceiros que vai rodar no CI: confira se os `source=` apontam para `download.nvidia.com` e se não há comando estranho.

- [ ] **Passo 5: commit**

```bash
git add tools/sync-aur.sh tests/sync-aur.bats packages/aur packages/ordem.txt
git commit -m "feat(aur): sync-aur e driver nvidia 580xx (Pascal) no repositório"
```

---

### Task 7: Workflow completo — compilar, publicar e testar o repositório

**Arquivos:**
- Modificar: `.github/workflows/repo.yml` (jobs `build` e `smoke`)
- Criar: `tests/smoke-repo.sh`

**Interfaces:**
- Consome: `ci-setup.sh` (Task 2), `build-repo.sh` (Task 3), `publish-release.sh` (Task 4), o secret `XINGUOS_GPG_KEY`, a variável `XINGUOS_GPG_FPR` e o `packages/ordem.txt`.
- **Job `build`** (`needs: testes`, só em `main`, `permissions: contents: write`):
  1. `ci-setup.sh`;
  2. `gpg --batch --import` do secret;
  3. `XINGUOS_GPG_FPR=${{ vars.XINGUOS_GPG_FPR }} tools/build-repo.sh packages/ordem.txt packages out`;
  4. `cp packages/xinguos/xinguos-keyring/xinguos.gpg out/`;
  5. `GH_TOKEN=${{ github.token }} GH_REPO=${{ github.repository }} tools/publish-release.sh out repo-x86_64`.
- **Job `smoke`** (`needs: build`, container `archlinux:latest` **limpo**, sem `ci-setup.sh`): roda `tests/smoke-repo.sh <url-do-servidor> <FPR>`. O script segue exatamente a sequência do README:
  1. habilita o multilib;
  2. `pacman-key --init`;
  3. baixa o `xinguos.gpg`, roda `pacman-key --add` e depois `--lsign-key <FPR>`;
  4. adiciona o bloco `[xinguos]` das Restrições globais ao `pacman.conf`;
  5. roda `pacman -Sy --noconfirm xinguos-keyring`;
  6. roda `pacman -Sw --noconfirm nvidia-580xx-utils nvidia-580xx-dkms lib32-nvidia-580xx-utils` (que baixa e **verifica as assinaturas**).
  
  Sai com 0 só se tudo passar.

- [ ] **Passo 1: escrever o `tests/smoke-repo.sh` e os jobs `build` e `smoke`**

- [ ] **Passo 2: push e verificação**

Rode: `gh run watch`.
Esperado: `testes`, `build` e `smoke` verdes.
Depois: `gh release view repo-x86_64` lista `xinguos.gpg`, `xinguos.db`, `xinguos.files` (com as `.sig`), `xinguos-keyring-*`, `nvidia-580xx-utils-*`, `nvidia-580xx-dkms-*` e `lib32-nvidia-580xx-utils-*`, cada um com sua `.sig`.

- [ ] **Passo 3: segunda execução sem mudanças** (`gh workflow run repo.yml`)

Esperado: verde, e a release com **a mesma lista** de assets, sem duplicatas.

- [ ] **Passo 4: commit**

```bash
git add .github/workflows/repo.yml tests/smoke-repo.sh
git commit -m "ci: compila, publica e testa o repositório [xinguos] de ponta a ponta"
```

---

### Task 8: Kit do Marco 0

**Arquivos:**
- Criar: `marco0/README.md` (roteiro dos Passos das Tasks 9 e 10, em português simples), `marco0/resultados.md` (modelo a preencher), `marco0/prototipo/steamos-session-select`, `marco0/prototipo/xinguos-escrever-sessao`, `marco0/prototipo/sudoers-xinguos-prototipo`, `marco0/prototipo/instalar.sh`

Tudo em `marco0/prototipo/` é **descartável**. A versão definitiva (helper com polkit e contador de falhas) é do Plano 3 (`xinguos-gaming`).

**Interfaces:**
- `steamos-session-select <plasma|desktop|gamescope|gaming>`, rodado pelo usuário:
  - `plasma|desktop` → sessão `plasma.desktop`;
  - `gamescope|gaming` → sessão `gamescope-session-steam.desktop`;
  - roda `sudo -n /usr/local/lib/xinguos/xinguos-escrever-sessao <sessão.desktop> "$USER"` e depois `loginctl terminate-session "$XDG_SESSION_ID"`;
  - argumento inválido → sai com código 2 e a mensagem `uso: steamos-session-select plasma|gamescope`.
- `xinguos-escrever-sessao <sessão.desktop> <usuário>`, rodado como root: grava `/etc/sddm.conf.d/zz-xinguos-session.conf` com:
  ```
  [Autologin]
  User=<usuário>
  Session=<sessão.desktop>
  Relogin=true
  ```
  Rejeita (código 2) sessão que não exista em `/usr/share/wayland-sessions/`.
- O `sudoers-xinguos-prototipo` libera `%wheel ALL=(root) NOPASSWD: /usr/local/lib/xinguos/xinguos-escrever-sessao`.
- O `instalar.sh` copia `steamos-session-select` para `/usr/local/bin/`, o helper para `/usr/local/lib/xinguos/` e o sudoers para `/etc/sudoers.d/` (validado com `visudo -cf` antes de copiar).

**Modelo do `resultados.md`:**
- uma tabela com os itens 1 a 6 da Task 10, com as colunas `Resultado (ok / ok com ajuste / falhou)`, `Notas` e `Plano B usado`;
- no fim, a linha `**Modo padrão da GTX 1060:** completo | compatível`.

- [ ] **Passo 1: escrever os arquivos.** Os scripts passam a ser incluídos no `shellcheck` do job `testes` (`shellcheck tools/*.sh marco0/prototipo/*`, exceto o sudoers).

- [ ] **Passo 2: push.** Esperado: `testes` verde.

- [ ] **Passo 3: commit**

```bash
git add marco0 .github/workflows/repo.yml
git commit -m "feat(marco0): roteiro, modelo de resultados e protótipo de troca de sessão"
```

---

## Adendo de 2026-11-08: Marco 0 em live boot, sem formatar

Pedido do Xingu: testar no PC real **sem formatar**, por uma ISO ao vivo com persistência no Ventoy, e continuar usando essa ISO durante o desenvolvimento.

**Ordem de execução:** Tasks 11 → 12 → 13 → 14 → 10.

A **Task 9 (formatar e instalar) foi adiada para o Plano 2** e não roda neste plano.

**Fatos conferidos:**
- Ventoy **1.1.17**, que é ≥ 1.1.09, a versão que corrigiu a persistência com ISOs Arch recentes.
- A partição `D:` é **exFAT** com o rótulo `Ventoy`.
- O `ventoy.json` atual tem `control` (`VTOY_DEFAULT_SEARCH_ROOT=/isos`) e `theme` (`display_mode=CLI`). **Esses dois precisam ser preservados.**
- O rótulo de persistência do Arch no Ventoy é `vtoycow`.

**Decisões:**
- O perfil base é o **`baseline`** do archiso, e não o `releng`, que tem muitas ferramentas de resgate e deixaria a ISO maior.
- A ISO sai como **artifact do Actions** (`gh run download`), não como asset de release, por causa do limite de 2 GB dos assets.
- A ISO tem **nome fixo**, `xinguos-teste.iso`, para a persistência continuar ligada a cada build novo.
- O live usa o kernel `linux`. O módulo NVIDIA é compilado pelo DKMS dentro do `mkarchiso`, e o patch 0001 do driver já liga o modeset por padrão.

### Task 11: gamescope-session no `[xinguos]` + perfil da ISO de teste (`tools/build-iso.sh`)

**Arquivos:**
- Gerados pelo `sync-aur.sh`: `packages/aur/gamescope-session-git/`, `packages/aur/gamescope-session-steam-git/`
- Modificar: `packages/ordem.txt` (acrescentar os dois, nessa ordem)
- Criar: `iso/teste/pacotes.txt`, `iso/teste/airootfs/...` (lista abaixo), `tools/build-iso.sh`, `tests/build-iso.bats`
- Modificar: `tools/ci-setup.sh` (instalar também o `archiso`)

**Interfaces:**
- `tools/build-iso.sh <overlay> <dir-saida> [--so-perfil]`, rodado como root. Lê `XINGUOS_REPO_URL` do ambiente (obrigatório). Passos:
  1. copia `/usr/share/archiso/configs/baseline` para um diretório temporário;
  2. acrescenta `<overlay>/pacotes.txt` ao `packages.x86_64`;
  3. copia `<overlay>/airootfs/.` para dentro do `airootfs/` do perfil;
  4. acrescenta ao `pacman.conf` do perfil os blocos `[multilib]` e `[xinguos]` (`SigLevel = Required DatabaseOptional`, `Server = $XINGUOS_REPO_URL`) e copia esse `pacman.conf` para `airootfs/etc/pacman.conf`;
  5. copia o protótipo do Marco 0:
     - `marco0/prototipo/steamos-session-select` → `airootfs/usr/local/bin/`;
     - `xinguos-escrever-sessao` → `airootfs/usr/local/lib/xinguos/`;
     - `sudoers-xinguos-prototipo` → `airootfs/etc/sudoers.d/xinguos-prototipo`;
  6. cria os links simbólicos de systemd (no Linux, não no git):
     - `display-manager.service` → `sddm.service`;
     - `multi-user.target.wants/NetworkManager.service`;
     - `multi-user.target.wants/xinguos-teste-usuario.service`;
  7. no `profiledef.sh`:
     - `iso_name="xinguos-teste"`, `iso_label="XINGUOS_TESTE"`, `iso_publisher="XInguOS <https://github.com/Guilherme-XHP/xinguos>"`;
     - `file_permissions` com `0:0:755` para os dois scripts do protótipo e para `/usr/local/bin/xinguos-teste-usuario`, e `0:0:440` para os dois arquivos de `/etc/sudoers.d/`;
  8. acrescenta ` cow_spacesize=8G` em toda linha que contém `archisobasedir=` nos arquivos de `grub/`, `syslinux/` e `efiboot/loader/entries/`. Sem persistência, o padrão de 256 MB não aguenta nem o Steam;
  9. se for `--so-perfil`, imprime o caminho do perfil e para (o perfil fica no disco). Senão, roda `mkarchiso -v -w <tmp>/work -o <dir-saida> <perfil>`, renomeia o resultado para `<dir-saida>/xinguos-teste.iso` e grava `xinguos-teste.iso.sha256`.

  Sai com código ≠ 0 se faltar o `XINGUOS_REPO_URL` ou o `<overlay>/pacotes.txt`.

- **`iso/teste/pacotes.txt`:**
  - `plasma-desktop sddm plasma-nm plasma-pa kscreen powerdevil konsole dolphin kate firefox xdg-desktop-portal-kde`
  - `pipewire pipewire-pulse wireplumber networkmanager`
  - `linux-headers xinguos-keyring nvidia-580xx-dkms nvidia-580xx-utils lib32-nvidia-580xx-utils`
  - `steam gamescope mangohud lib32-mangohud gamescope-session-git gamescope-session-steam-git`
  - `git github-cli sudo`

- **Arquivos em `iso/teste/airootfs/`:**
  - `etc/hostname`: `xinguos-teste`.
  - `etc/vconsole.conf`: `KEYMAP=br-abnt2`.
  - `etc/X11/xorg.conf.d/00-keyboard.conf`: `XkbLayout "br"`, `XkbModel "abnt2"`.
  - `etc/sddm.conf.d/10-xinguos-teste.conf`: `[Autologin]` com `User=xingu`, `Session=plasma.desktop` e `Relogin=true`. O `zz-xinguos-session.conf` do protótipo vem depois na ordem e, por isso, ganha.
  - `etc/sudoers.d/10-xinguos-teste`: `%wheel ALL=(ALL:ALL) NOPASSWD: ALL`. **Só na ISO de teste.**
  - `usr/local/bin/xinguos-teste-usuario`: se o usuário `xingu` não existe, roda `useradd -m -G wheel xingu` e `passwd -d xingu`. Se já existe (veio da persistência), não faz nada.
  - `etc/systemd/system/xinguos-teste-usuario.service`: oneshot, `Before=display-manager.service`, `WantedBy=multi-user.target`.

- [ ] **Passo 1: copiar a gamescope-session do AUR.** Rode `tools/sync-aur.sh gamescope-session-git` e `tools/sync-aur.sh gamescope-session-steam-git`. **Leia os PKGBUILDs inteiros** (é código de terceiros) e acrescente os dois ao `ordem.txt`.
- [ ] **Passo 2: escrever o `tests/build-iso.bats`**, usando `--so-perfil` e `XINGUOS_REPO_URL=https://exemplo.invalid/repo`. Testes:
  - `@test "perfil leva os pacotes do XInguOS"`: o `packages.x86_64` contém as linhas `nvidia-580xx-dkms`, `gamescope-session-steam-git` e `plasma-desktop`.
  - `@test "pacman.conf do perfil e do live têm [multilib] e [xinguos]"`: os dois arquivos contêm `[xinguos]` e `Server = https://exemplo.invalid/repo`.
  - `@test "protótipo e sudoers entram com permissões"`: o `profiledef.sh` contém `["/usr/local/bin/steamos-session-select"]="0:0:755"` e `["/etc/sudoers.d/xinguos-prototipo"]="0:0:440"`, e os arquivos existem no `airootfs`.
  - `@test "sddm e usuário habilitados"`: `airootfs/etc/systemd/system/display-manager.service` é um link para `/usr/lib/systemd/system/sddm.service` e existe o link `multi-user.target.wants/xinguos-teste-usuario.service`.
  - `@test "boot com cow_spacesize"`: toda linha com `archisobasedir=` contém `cow_spacesize=8G`, e há pelo menos uma.
  - `@test "sem XINGUOS_REPO_URL falha"`: status ≠ 0 e a saída contém `XINGUOS_REPO_URL`.
- [ ] **Passo 3: push.** Esperado: os 6 testes novos **FALHAM** porque o `build-iso.sh` não existe.
- [ ] **Passo 4: implementar o `tools/build-iso.sh` e os arquivos do overlay.** Acrescente `archiso` ao `pacman -S` do `ci-setup.sh`.
- [ ] **Passo 5: push.** Esperado: `testes` verde.
- [ ] **Passo 6: commit** — `feat(iso): perfil da ISO de teste ao vivo e gamescope-session no [xinguos]`.

### Task 12: `marco0/criar-persistencia.sh` — persistência no Ventoy

**Arquivos:**
- Criar: `marco0/criar-persistencia.sh`, `tests/criar-persistencia.bats`

**Interfaces:**
- `marco0/criar-persistencia.sh [--raiz <dir>] [--tamanho <tamanho>]`. Roda **no live da ISO de teste**, como root.
  - Padrão da `--raiz`: monta a partição de rótulo `Ventoy` (`/dev/disk/by-label/Ventoy`) em `/mnt/ventoy`. Os testes passam uma pasta comum.
  - Padrão do `--tamanho`: `80G`.
  - Cria `<raiz>/persistence/xinguos-teste.dat` com `fallocate -l`, caindo para `truncate -s` se o `fallocate` falhar, e formata com `mkfs.ext4 -F -L vtoycow`.
  - Atualiza o `<raiz>/ventoy/ventoy.json`, **preservando** as chaves existentes. Acrescenta, ou substitui pelo mesmo `image`, a entrada `{"image": "/isos/Linux/xinguos-teste.iso", "backend": "/persistence/xinguos-teste.dat"}` na lista `persistence`. Usa o `python` do live, porque o `jq` não vem na ISO. Antes de mexer, faz backup em `ventoy.json.antes-xinguos`.
  - Se o `.dat` já existe, recusa (código 1) sem tocar em nada. Recriar apagaria a persistência.
- Na ISO, o arquivo vai para `/usr/local/bin/criar-persistencia` (`0:0:755`). O `build-iso.sh` copia e o `file_permissions` cobre. Acrescente isso ao Passo 5/7 da Task 11 por meio desta task, com um teste extra no `build-iso.bats`: `@test "criar-persistencia vai pra ISO"`.

- [ ] **Passo 1: escrever os testes** (rodam como root no CI, numa pasta temporária, com `--tamanho 64M`):
  - `@test "cria imagem ext4 com rótulo vtoycow"`: `e2label <dat>` imprime `vtoycow`.
  - `@test "preserva control e theme e acrescenta persistence"`: partindo do `ventoy.json` real do Xingu, citado no topo do adendo, o resultado tem `control[0].VTOY_DEFAULT_SEARCH_ROOT == "/isos"`, `theme.display_mode == "CLI"` e `persistence[0].backend == "/persistence/xinguos-teste.dat"`. Checagem com `python -c`.
  - `@test "rodar duas vezes não duplica nem apaga"`: na segunda execução o status é 1, a lista `persistence` continua com 1 entrada e o `.dat` não muda (mesma data de modificação).
  - `@test "faz backup do ventoy.json"`: `ventoy.json.antes-xinguos` é igual ao original.
- [ ] **Passo 2: push.** Esperado: **FALHA** nos testes.
- [ ] **Passo 3: implementar o script e o teste extra do `build-iso.bats`.** Inclua o script no `shellcheck` do workflow.
- [ ] **Passo 4: push.** Esperado: verde.
- [ ] **Passo 5: commit** — `feat(marco0): script de persistência do Ventoy para a ISO de teste`.

### Task 13: Job `iso-teste` no CI

**Arquivos:**
- Modificar: `.github/workflows/repo.yml`
- Criar: `tools/confiar-xinguos.sh` (os passos 1 a 3 do README: chave + bloco + keyring). Ele é extraído do `tests/smoke-repo.sh`, que passa a chamá-lo.

**Interfaces:**
- `tools/confiar-xinguos.sh <url> <fpr>`: os mesmos comandos que hoje estão no smoke, do `pacman-key --init` até `pacman -Sy --noconfirm xinguos-keyring`.
- Job **`iso-teste`**:
  - roda só em `workflow_dispatch` com o input booleano `iso` igual a `true`, ou seja `gh workflow run repo.yml --ref <branch> -f iso=true`;
  - `needs: smoke`, `container: archlinux:latest` com `options: --privileged`;
  - passos: `ci-setup.sh`, depois `confiar-xinguos.sh`, depois `XINGUOS_REPO_URL=... tools/build-iso.sh iso/teste out-iso`;
  - verifica com `test -s out-iso/xinguos-teste.iso` e imprime `du -h`;
  - publica com `actions/upload-artifact@v4`: nome `xinguos-teste-iso`, caminho `out-iso/`, `retention-days: 30`, `compression-level: 0`.

- [ ] **Passo 1: refatorar o smoke para usar o `confiar-xinguos.sh`.** Rode o workflow com `gh workflow run repo.yml --ref plano1`. Esperado: `smoke` continua verde. Esse é o teste da refatoração.
- [ ] **Passo 2: acrescentar o input `iso` e o job `iso-teste`.** Rode `gh workflow run repo.yml --ref plano1 -f iso=true` e depois `gh run watch`. Esperado: `iso-teste` verde, com o artifact `xinguos-teste-iso` listado em `gh run view <id>`.
- [ ] **Passo 3: baixar e conferir no Windows.** Rode `gh run download <id> -n xinguos-teste-iso -D <scratch>` e depois `sha256sum -c xinguos-teste.iso.sha256`. Esperado: `OK`. Mova para `D:\isos\Linux\xinguos-teste.iso`.
- [ ] **Passo 4: commit** — `ci: job iso-teste gera a ISO ao vivo como artifact`.

### Task 14: [MANUAL — Xingu] Primeiro boot ao vivo e persistência

Substitui a Task 9 neste plano.

- [ ] **Passo 1:** No PC, escolha `xinguos-teste.iso` no menu do Ventoy, **sem** persistência (ela ainda não existe). Esperado: o SDDM entra sozinho no Plasma como `xingu`.
- [ ] **Passo 2:** No Konsole, rode `sudo criar-persistencia` (80 GB; no HD USB leva uns 15 a 25 minutos). Esperado: termina com a linha da entrada do `ventoy.json` e `vtoycow`.
- [ ] **Passo 3:** Reinicie e escolha a ISO de novo. Agora o Ventoy oferece a persistência: escolha `xinguos-teste.dat`. Para conferir:
  - crie um arquivo em `~`, reinicie e veja se ele continua lá;
  - `nvidia-smi` mostra a GTX 1060 com o driver `580.`;
  - `cat /sys/module/nvidia_drm/parameters/modeset` mostra `Y`;
  - `echo $XDG_SESSION_TYPE` mostra `wayland`.
- [ ] **Passo 4:** Rode `gh auth login` e depois `gh repo clone Guilherme-XHP/xinguos`. Siga para a Task 10, rodando os testes no live, com persistência.

  Ajustes da Task 10 no live:
  - o Steam, o gamescope e a gamescope-session **já vêm na ISO**;
  - o protótipo **já vem instalado** (pule o `instalar.sh`);
  - o Kdenlive e o GIMP do item 5 são instalados com `sudo pacman -S` na persistência.

---

### Task 9: [ADIADA para o Plano 2] Backup e instalação do Arch no SSD

Pelo adendo de 2026-11-08, esta task não roda neste plano. Ela fica aqui como referência para o Plano 2.

Este Arch vira a base de uso diário no Plano 2, então ele não é jogado fora.

**Discos (conferidos em 2026-11-08):**
- **Disco 0:** SanDisk SSD PLUS 1 TB (o `C:`). É **o único que será formatado**.
- **Disco 1:** HD USB Seagate de 500 GB, que é **o próprio Ventoy**, com a partição `D:` (backups em `D:\Guilherme`, ISOs em `D:\isos\Linux`) e a partição `F:` (EFI do Ventoy). Esse disco **nunca** pode ser escolhido no instalador.

- [ ] **Passo 1: backup em `D:\Guilherme`.** Copie pelo menos:
  - `C:\XIngu` inteiro (madrugada, robozinho-lab, kdenlive-tweaks, backup, xinguos);
  - Documentos, Imagens e Vídeos;
  - saves de jogos sem Steam Cloud;
  - o `privada-xinguos.asc` (que já deve estar lá desde a Task 5).

  Havia 322 GB livres em 2026-11-08.

  Para conferir: abra 3 arquivos aleatórios da cópia.

- [ ] **Passo 2: ISO.** Use a `D:\isos\Linux\archlinux-x86_64.iso` (de 11/10/2026), bootando pelo Ventoy do próprio HD. Se o `archinstall` reclamar de keyring ou assinatura, rode `pacman -Sy archlinux-keyring` no modo ao vivo e tente de novo.

  As ISOs do XInguOS (Plano 6) também vão para `D:\isos\Linux`.

- [ ] **Passo 3: instalar com o `archinstall`.** Escolhas:

| Opção | Valor |
|---|---|
| Idioma e locale | pt_BR.UTF-8; teclado `br-abnt2` |
| Disco | **SanDisk SSD PLUS 1000GB** (~932 GB) → apagar tudo → **btrfs** com os subvolumes padrão, compressão ligada. ⚠️ **Nunca** o ST500LM0 de ~466 GB, que é o HD do Ventoy com todos os backups. |
| Snapshots | snapper |
| Bootloader | GRUB |
| Kernels | `linux-zen` e `linux-lts` |
| Perfil | Desktop → KDE Plasma, gerenciador de login SDDM |
| **Driver gráfico** | **"All open-source"**. ⚠️ **Não** escolha "Nvidia (proprietary)": ele instala o `nvidia-open`, que não funciona na 1060. |
| Áudio | PipeWire |
| Repositórios extras | **multilib** |
| Pacotes extras | `linux-zen-headers linux-lts-headers git firefox` |
| Fuso | America/Sao_Paulo |

- [ ] **Passo 4: instalar o driver pelo `[xinguos]`** (primeiro uso real do repositório)

Siga o README: adicione a chave, coloque o bloco `[xinguos]` no `/etc/pacman.conf` e instale o `xinguos-keyring`. Depois:
```
sudo pacman -Sy nvidia-580xx-dkms nvidia-580xx-utils lib32-nvidia-580xx-utils
```
Em `/etc/default/grub`, acrescente `nvidia-drm.modeset=1` ao `GRUB_CMDLINE_LINUX_DEFAULT`. Depois rode `sudo grub-mkconfig -o /boot/grub/grub.cfg` e reinicie.

Para conferir:
- `nvidia-smi` mostra `GeForce GTX 1060 6GB` e o driver `580.`;
- `cat /sys/module/nvidia_drm/parameters/modeset` mostra `Y`;
- no Plasma, `echo $XDG_SESSION_TYPE` mostra `wayland`.

- [ ] **Passo 5: instalar o Claude Code no Arch** (instalador oficial) e clonar o repositório: `gh repo clone xinguos`. As próximas sessões continuam por ali.

---

### Task 10: [MANUAL — Xingu] Testes do Marco 0 e decisão

Siga o `marco0/README.md` e anote cada item no `marco0/resultados.md`.

- [ ] **Item 1 — Plasma Wayland estável com o 580xx:** 15 minutos de uso normal (Firefox, Dolphin, um vídeo). Passa se não congelar nem piscar e se `journalctl -b -p err | grep -i nvidia` vier vazio ou só com avisos inofensivos.
- [ ] **Item 2 — gamescope embutido:** instale `steam gamescope mangohud lib32-mangohud`, saia do Plasma, vá para a TTY3 (Ctrl+Alt+F3) e rode `gamescope -e -- steam -gamepadui`. Passa se a interface do Deck abrir, um jogo iniciar e **a tela não ficar preta** com o cursor parado/escondido por 2 minutos. **Tela preta = falhou → modo compatível.**
- [ ] **Item 3 — troca de sessão:**
  1. instale `gamescope-session-git` e `gamescope-session-steam-git` pelo AUR (`git clone` + `makepkg -si`; ainda não estão no `[xinguos]`);
  2. confira se existe `/usr/share/wayland-sessions/gamescope-session-steam.desktop`;
  3. rode `sudo marco0/prototipo/instalar.sh`;
  4. entre na sessão Steam pelo SDDM → "Mudar para a Área de Trabalho" → cai no Plasma → `steamos-session-select gamescope` → volta pro Steam.

  Passa se fizer o ciclo **3 vezes** sem pedir senha e sem travar.
- [ ] **Item 4 — VR:** instale o SteamVR pelo Steam, abra o Steam Link no Quest 2, conecte e jogue Half-Life: Alyx por 10 minutos. Anote FPS, travadas e áudio. Se falhar, anote o erro. O plano B (WiVRn) só é testado se o Xingu quiser.
- [ ] **Item 5 — menu global:** adicione o widget "Menu global" ao painel de cima. Teste o Kdenlive, o Dolphin e o GIMP (`sudo pacman -S kdenlive gimp`) e anote em quais o menu foi pro topo.
- [ ] **Item 6 — desktop parado:** 5 minutos sem mexer, com `top` aberto. Passa se nenhum processo ficar subindo a CPU acima de 10% de forma recorrente. Anote os culpados (Baloo, etc.).
- [ ] **Decisão:** preencha `Modo padrão da GTX 1060: completo` se o item 2 e o item 3 passaram; `compatível` se o item 2 falhou.
- [ ] **Commit:**

```bash
git add marco0/resultados.md
git commit -m "docs(marco0): resultados na GTX 1060 e modo padrão do Gaming Mode"
git push
```

---

## Próximos planos (cada um escrito depois que o anterior terminar)

- **Plano 2:** `xinguos-base` + `xinguos-hwdetect` (com `xinguos-nvidia-guard`). Aplicado sobre o Arch da Task 9.
- **Plano 3:** `xinguos-gaming` (sessões, `xinguos-session-select` com polkit, comandos falsos do SteamOS, contador de falhas, modo compatível), usando o resultado do Marco 0.
- **Plano 4:** `xinguos-desktop` + `xinguos-apps`.
- **Plano 5:** `xinguos-foco`.
- **Plano 6:** ISO + Calamares + `xinguos-boasvindas` + `xinguos-branding` provisório.
