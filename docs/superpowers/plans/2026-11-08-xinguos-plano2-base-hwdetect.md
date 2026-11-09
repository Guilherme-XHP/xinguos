# XInguOS — Plano 2: `xinguos-base` + `xinguos-hwdetect`

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Objetivo:** a base do sistema (ajustes de desempenho, serviços, snapshots, ferramentas) e a detecção de GPU, que escolhe o driver certo e protege a GTX 10xx do driver 590.

**Arquitetura:**
- Três pacotes novos no `[xinguos]`:
  - `xinguos-base`: configurações + dependências, **sem kernel**;
  - `xinguos-kernels`: `linux-zen` + `linux-lts`, cada um com os headers;
  - `xinguos-hwdetect`: um script bash com modos `--detectar`, `--apply`, `--hook` e `--guard`, mais dois hooks do pacman.
- As configurações ficam nos diretórios de fornecedor (`/usr/lib/...`, `/usr/share/...`). Assim, qualquer arquivo em `/etc` do usuário ganha (spec 2.4).
- Os testes rodam no CI: bats para a lógica e as configurações, instalação real num Arch limpo no smoke, e a ISO de teste no PC do Xingu.

**Stack:** bash, bats, pacman/makepkg, hooks do libalpm, systemd (zram-generator, oomd, journald, udev), pciutils.

**Spec:** `docs/superpowers/specs/2026-11-08-xinguos-design.md` (seções 2.1, 2.4, 3, 5.4, 7.1). O Plano 1 já está feito: infra do repositório, CI e ISO de teste.

**Branch:** `plano2`, criado a partir do `main`.

## Restrições globais

- Tudo o que vale no Plano 1 continua valendo:
  - `set -euo pipefail`;
  - shellcheck limpo;
  - LF;
  - commits em português com `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`;
  - nada roda localmente, o CI é o ambiente de teste.
- **Nome de pacote publicado é imutável.** Qualquer mudança no conteúdo de um pacote exige subir o `pkgrel` ou o `pkgver`. A Task 1 faz o CI falhar quando alguém esquece disso.
- Versão inicial dos pacotes novos: `pkgver=0.1.0`, `pkgrel=1`, `arch=(any)`, `license=(GPL-3.0-or-later)`, `url="https://github.com/Guilherme-XHP/xinguos"`.
- Configurações do XInguOS só em `/usr/lib`, `/usr/share` e `/etc/xdg`. **Nunca** escrever arquivo de config do usuário em `/etc`. A exceção são os arquivos que o `xinguos-hwdetect --apply` gera de propósito: `/etc/xinguos/gaming.conf` e `/etc/modprobe.d/xinguos-nvidia.conf`.
- Valores do spec (seção 7.1):
  - zram: `zram-size = ram / 2`, `compression-algorithm = zstd`;
  - `vm.swappiness=180`, `vm.page-cluster=0`;
  - journald: `SystemMaxUse=200M`;
  - BFQ em disco rotacional e `none` em SSD/NVMe;
  - `fstrim.timer` habilitado;
  - `systemd-oomd` para as user slices;
  - `cups` fora da base;
  - Snapper com limite de 10 snapshots.

## Foco da revisão

1. **Desktop com a iGPU Intel ligada + GTX 1060:** o `lspci` mostra duas GPUs e o perfil vira `varias`, que não instala nada. A pessoa precisa receber um aviso dizendo **como forçar** (`--forcar nvidia-580xx`) e não pode ficar sem saída (teste na Task 2).
2. **Reinstalar ou atualizar o `xinguos-hwdetect`** nunca pode sobrescrever a escolha do usuário em `/etc/xinguos/gaming.conf` (teste na Task 3).
3. **O guard só pode bloquear quem tem GPU Pascal/Maxwell/Volta.** Quem tem RTX e instala o `nvidia-open-dkms` passa livre (teste na Task 4).
4. **O `--apply` falha no meio** (sem internet ou pacman negado): não pode sobrar `modprobe.d` nem `gaming.conf` meio escritos (teste na Task 3).
5. **Mudar um arquivo de pacote e esquecer o `pkgrel`:** sem a Task 1, o CI publicaria os bytes antigos em silêncio. Com ela, o CI falha e diz qual pacote mudou (teste na Task 1).

---

### Task 1: `build-repo.sh` recusa conteúdo novo com nome antigo

**Arquivos:**
- Modificar: `tools/build-repo.sh`, `tests/build-repo.bats`

**Interfaces:**
- Produz: dentro do `build-repo.sh`, quando um pacote compilado tem o mesmo nome de um que está em `XINGUOS_PUBLICADOS`, o script compara o **conteúdo** dos dois antes de reaproveitar:
  - a lista `caminho + sha256` de todos os arquivos regulares, exceto `.BUILDINFO`, `.MTREE` e `.PKGINFO`;
  - o `.PKGINFO` sem as linhas `builddate`, `packager` e `size`.
- Se for igual, reaproveita como hoje. Se for diferente, sai com código ≠ 0 e a mensagem `conteúdo mudou sem subir pkgrel: <arquivo>`, sem gerar banco.
- Implementação: uma função `assinatura_conteudo <pkg>` que extrai com `bsdtar -xf` para um diretório temporário e imprime as linhas ordenadas.

- [ ] **Passo 1: escrever o teste** `@test "conteúdo mudou com o mesmo nome falha"`:
  1. compila `ordem-ok.txt` em `$pub`;
  2. copia `tests/fixtures/pacotes` para um diretório temporário e acrescenta `touch "$pkgdir/usr/share/xg-teste-a/novo"` ao `package()` do `xg-teste-a`;
  3. com `XINGUOS_PUBLICADOS="$pub"`, compila de novo;
  4. espera status ≠ 0, a saída contendo `conteúdo mudou sem subir pkgrel: xg-teste-a-1-1-any.pkg.tar.zst` e nenhum `xinguos.db`.
- [ ] **Passo 2: push.** Esperado: **FALHA** (hoje o script reaproveita em silêncio).
- [ ] **Passo 3: implementar.**
- [ ] **Passo 4: push.** Esperado: verde, e o teste "reaproveitado byte a byte" continua passando.
- [ ] **Passo 5: commit** — `fix(repo): build-repo recusa conteúdo novo com nome de pacote já publicado`

### Task 2: `xinguos-hwdetect --detectar`

**Arquivos:**
- Criar: `packages/xinguos/xinguos-hwdetect/xinguos-hwdetect`, `tests/hwdetect.bats`, `tests/fixtures/lspci/*.txt`

**Interfaces:**
- `xinguos-hwdetect --detectar` imprime exatamente 4 linhas `chave=valor` e sai com 0:
  ```
  perfil=<nvidia-580xx|nvidia-open|amd|intel|varias|nvidia-legada|desconhecida>
  pacotes=<lista separada por espaço, pode ser vazia>
  gaming=<completo|compativel>
  aviso=<texto, pode ser vazio>
  ```
- **Entrada:** a saída de `lspci -nn`. Para os testes, se `XINGUOS_LSPCI_ARQUIVO` estiver definido, o script lê esse arquivo em vez de rodar o `lspci`.
- **Quais linhas contam como GPU:** as de classe `[0300]`, `[0302]` ou `[0380]`. O `vendor:device` sai do **último** `[xxxx:xxxx]` da linha.
- **Regra de decisão** (o NVIDIA usa o device ID em hexadecimal):

| Condição | perfil | pacotes | gaming |
|---|---|---|---|
| mais de uma GPU | `varias` | (vazio) | `compativel` |
| uma GPU `10de`, `0x1340 ≤ id < 0x1E00` (Maxwell/Pascal/Volta) | `nvidia-580xx` | `nvidia-580xx-dkms nvidia-580xx-utils lib32-nvidia-580xx-utils` | `compativel` |
| uma GPU `10de`, `id ≥ 0x1E00` (Turing+) | `nvidia-open` | `nvidia-open-dkms nvidia-utils lib32-nvidia-utils` | `completo` |
| uma GPU `10de`, `id < 0x1340` (Kepler e anteriores) | `nvidia-legada` | (vazio) | `compativel` |
| uma GPU `1002` | `amd` | `mesa lib32-mesa vulkan-radeon lib32-vulkan-radeon` | `completo` |
| uma GPU `8086` | `intel` | `mesa lib32-mesa vulkan-intel lib32-vulkan-intel` | `completo` |
| nenhuma GPU | `desconhecida` | (vazio) | `compativel` |

- **Avisos:**
  - em `varias`: `aviso=mais de uma GPU encontrada; nada foi instalado. Para escolher, rode: sudo xinguos-hwdetect --apply --forcar <perfil>`;
  - em `nvidia-legada`: `aviso=GPU NVIDIA antiga demais para o driver 580; usando o driver livre (nouveau)`;
  - em `desconhecida`: `aviso=nenhuma GPU reconhecida; nada foi instalado`.
- **Fixtures** (uma linha cada, copiadas de `lspci -nn` reais):
  - `gtx1060.txt`: `01:00.0 VGA compatible controller [0300]: NVIDIA Corporation GP106 [GeForce GTX 1060 6GB] [10de:1c03] (rev a1)`;
  - `rtx2060.txt` com `[10de:1f08]`;
  - `gtx650.txt` com `[10de:0fc6]`;
  - `rx6600.txt` com `[1002:73ff]`;
  - `uhd630.txt` com `[8086:9bc5]`;
  - `notebook.txt` com Intel `[0300]` + NVIDIA `3D controller [0302]` `[10de:1c8d]`;
  - `sem-gpu.txt`, só com uma linha `Ethernet controller [0200]`.

- [ ] **Passo 1: escrever os testes**, um por fixture. Cada um checa as 4 linhas exatas da tabela. Exemplos:
  - `@test "GTX 1060 → nvidia-580xx compatível"`;
  - `@test "duas GPUs → varias, sem pacotes, aviso ensina --forcar"`: `[[ "$output" == *"--forcar"* ]]`;
  - `@test "saída tem sempre 4 linhas"`: roda com todas as fixtures.
- [ ] **Passo 2: push.** Esperado: **FALHA** (o script não existe).
- [ ] **Passo 3: implementar o `--detectar`.** Inclua o arquivo no `shellcheck` do workflow.
- [ ] **Passo 4: push.** Esperado: verde.
- [ ] **Passo 5: commit** — `feat(hwdetect): detecção de GPU e escolha de perfil`

### Task 3: `--apply`, `--forcar` e `--hook`

**Arquivos:**
- Modificar: `packages/xinguos/xinguos-hwdetect/xinguos-hwdetect`, `tests/hwdetect.bats`
- Criar: `tests/stubs/pacman` (registra `"$*"` em `$PACMAN_LOG` e sai com `${PACMAN_STATUS:-0}`)

**Interfaces:**
- **Variáveis de ambiente para testes:**
  - `XINGUOS_ETC` (padrão `/etc/xinguos`);
  - `XINGUOS_MODPROBE_DIR` (padrão `/etc/modprobe.d`).
- **`--apply [--forcar <perfil>]`** (root):
  1. calcula o perfil com a regra da Task 2. O `--forcar` troca o perfil e os pacotes/gaming correspondentes; perfil inválido sai com código 2;
  2. se `pacotes` não estiver vazio, roda `pacman -S --needed <pacotes>`, **interativo** (sem `--noconfirm`, porque trocar de driver pede confirmação de conflito). Se o pacman falhar, sai com código ≠ 0 **antes** de escrever qualquer arquivo;
  3. se o perfil for `nvidia-580xx` ou `nvidia-open`, grava `$XINGUOS_MODPROBE_DIR/xinguos-nvidia.conf` com `options nvidia_drm modeset=1`;
  4. grava `$XINGUOS_ETC/gaming.conf` com `MODO_GAMING=<gaming>` **só se o arquivo não existir**.
- **`--hook`** (chamado pelo hook do pacman; nunca instala nada e sempre sai com 0):
  - calcula o perfil;
  - grava o `gaming.conf` só se não existir;
  - se algum pacote do perfil não estiver instalado (`pacman -Q <pkg>` falha), imprime `xinguos-hwdetect: para a sua GPU (<perfil>), rode: sudo xinguos-hwdetect --apply`;
  - imprime o `aviso`, se houver.
- **Desvio do spec, registrado no ledger:** o spec pede `nvidia-drm.modeset=1` na linha do kernel. O plano usa `options nvidia_drm modeset=1` em `modprobe.d`, que tem o mesmo efeito para o módulo e não exige mexer no GRUB. E o patch 0001 do driver já liga o modeset por padrão.
- **Outro desvio do spec, registrado no ledger:** a seção 3(b) do spec dizia "instala por hook". Só que um hook do pacman **não pode** rodar o pacman, porque a trava do banco está ocupada. Por isso o hook só detecta e avisa. Quem instala é o `--apply`, chamado à mão, pelo Calamares ou pelo app de boas-vindas.

- [ ] **Passo 1: escrever os testes** (com o `tests/stubs` no PATH):
  - `@test "--apply instala os pacotes do perfil e grava modprobe e gaming.conf"`: com a GTX 1060, o log do pacman contém `-S --needed nvidia-580xx-dkms nvidia-580xx-utils lib32-nvidia-580xx-utils`, `xinguos-nvidia.conf` contém `options nvidia_drm modeset=1` e `gaming.conf` contém `MODO_GAMING=compativel`;
  - `@test "--apply não sobrescreve gaming.conf existente"`: com `MODO_GAMING=completo` já gravado, continua `completo`;
  - `@test "pacman falhou → nada é escrito"`: com `PACMAN_STATUS=1`, o status é ≠ 0 e nem `xinguos-nvidia.conf` nem `gaming.conf` existem;
  - `@test "--forcar escolhe o perfil mesmo com duas GPUs"`: `notebook.txt` + `--forcar nvidia-580xx` instala os pacotes do 580xx;
  - `@test "--forcar com perfil inválido sai 2"`;
  - `@test "--hook avisa quando falta driver e não chama pacman -S"`: o stub de `pacman -Q` falha; a saída contém `rode: sudo xinguos-hwdetect --apply`; nenhum `-S` no log; status 0;
  - `@test "--hook não sobrescreve gaming.conf"`.
- [ ] **Passo 2: push.** Esperado: **FALHA**.
- [ ] **Passo 3: implementar.**
- [ ] **Passo 4: push.** Esperado: verde.
- [ ] **Passo 5: commit** — `feat(hwdetect): --apply, --forcar e modo hook`

### Task 4: `--guard` + hooks do pacman + pacote `xinguos-hwdetect`

**Arquivos:**
- Modificar: `packages/xinguos/xinguos-hwdetect/xinguos-hwdetect`, `tests/hwdetect.bats`, `packages/ordem.txt` (acrescentar `xinguos/xinguos-hwdetect`)
- Criar:
  - `packages/xinguos/xinguos-hwdetect/PKGBUILD`;
  - `.../90-xinguos-hwdetect.hook`;
  - `.../10-xinguos-nvidia-guard.hook`.

**Interfaces:**
- **`--guard`:** se o perfil for `nvidia-580xx`, imprime a mensagem abaixo e sai com 1. Em qualquer outro perfil, sai com 0.
  > `xinguos-nvidia-guard: esta GPU (Maxwell/Pascal/Volta) só funciona com o driver 580xx. A transação foi cancelada para não deixar o sistema sem vídeo. Use os pacotes nvidia-580xx-* do [xinguos].`
- **`10-xinguos-nvidia-guard.hook`:** `[Trigger] Operation = Install` e `Operation = Upgrade`, `Type = Package`, `Target =` `nvidia`, `nvidia-dkms`, `nvidia-lts`, `nvidia-open`, `nvidia-open-dkms`, `nvidia-open-lts` e `nvidia-utils`. `[Action] When = PreTransaction`, `Exec = /usr/bin/xinguos-hwdetect --guard`, `AbortOnFail`.
- **`90-xinguos-hwdetect.hook`:** Install/Upgrade, `Target = xinguos-hwdetect`, `When = PostTransaction`, `Exec = /usr/bin/xinguos-hwdetect --hook`.
- **PKGBUILD:**
  - `depends=(pciutils)`;
  - instala o script em `/usr/bin/xinguos-hwdetect` (755) e os hooks em `/usr/share/libalpm/hooks/` (644);
  - usa `source=` com os arquivos locais e `sha256sums=(SKIP ...)`, como no keyring.

- [ ] **Passo 1: escrever os testes:**
  - `@test "--guard bloqueia GTX 1060"`: status 1 e a saída contém `só funciona com o driver 580xx`;
  - `@test "--guard libera RTX, AMD e várias GPUs"`: status 0 nos três;
  - `@test "hook do guard é PreTransaction com AbortOnFail e cobre nvidia-open-dkms e nvidia-utils"`: greps no arquivo;
  - `@test "hook do hwdetect roda --hook só para o próprio pacote"`.
- [ ] **Passo 2: push.** Esperado: **FALHA**.
- [ ] **Passo 3: implementar o `--guard`, os hooks e o PKGBUILD.** Acrescente o pacote ao `ordem.txt`.
- [ ] **Passo 4: push.** Esperado: `testes` verde. Depois, `gh workflow run repo.yml --ref plano2`: `build` verde e `xinguos-hwdetect-0.1.0-1-any.pkg.tar.zst` na release.
- [ ] **Passo 5: commit** — `feat(hwdetect): guard do driver NVIDIA e pacote xinguos-hwdetect`

### Task 5: `paru-bin` no `[xinguos]`

**Arquivos:**
- Gerados pelo `sync-aur.sh`: `packages/aur/paru-bin/`
- Modificar: `packages/ordem.txt` (acrescentar `aur/paru-bin`)

- [ ] **Passo 1:** rode `tools/sync-aur.sh paru-bin` e **leia o PKGBUILD inteiro**. Confira se o `source=` aponta só para `github.com/Morganamilo/paru/releases` e se existe `sha256sums` (não `SKIP`). Registre no ledger.
- [ ] **Passo 2:** acrescente `aur/paru-bin` ao `ordem.txt` e rode o workflow com dispatch. Esperado: `build` verde e `paru-bin-2.2.0-1-x86_64.pkg.tar.zst` na release.
- [ ] **Passo 3: commit** — `feat(aur): paru-bin no [xinguos]`

### Task 6: pacotes `xinguos-base` e `xinguos-kernels`

**Arquivos:**
- Criar em `packages/xinguos/xinguos-base/`:
  - `PKGBUILD`, `xinguos-base.install`;
  - `zram-generator.conf`, `90-xinguos.sysctl.conf`;
  - `60-xinguos-ioschedulers.rules`, `90-xinguos-journald.conf`;
  - `90-xinguos-oomd-user.conf`, `90-xinguos-oomd-root.conf`;
  - `snapper-xinguos`.
- Criar: `packages/xinguos/xinguos-kernels/PKGBUILD`, `tests/base.bats`
- Modificar: `packages/ordem.txt` (acrescentar `xinguos/xinguos-kernels` e `xinguos/xinguos-base`, **depois** de `aur/paru-bin`)

**Interfaces:**
- **`xinguos-kernels`:** pacote meta, `depends=(linux-zen linux-zen-headers linux-lts linux-lts-headers)`.
- **`xinguos-base`:**
  - `depends=(xinguos-keyring xinguos-hwdetect intel-ucode amd-ucode linux-firmware pipewire pipewire-pulse pipewire-jack wireplumber networkmanager bluez bluez-utils zram-generator btrfs-progs snapper snap-pac grub-btrfs paru-bin flatpak)`. **Sem kernel.**
- **Arquivos instalados:**

| Origem | Destino | Conteúdo |
|---|---|---|
| `zram-generator.conf` | `/usr/lib/systemd/zram-generator.conf` | `[zram0]` / `zram-size = ram / 2` / `compression-algorithm = zstd` |
| `90-xinguos.sysctl.conf` | `/usr/lib/sysctl.d/90-xinguos.conf` | `vm.swappiness = 180` / `vm.page-cluster = 0` |
| `60-xinguos-ioschedulers.rules` | `/usr/lib/udev/rules.d/60-xinguos-ioschedulers.rules` | `ACTION=="add\|change", KERNEL=="sd[a-z]*\|mmcblk[0-9]*", ATTR{queue/rotational}=="1", ATTR{queue/scheduler}="bfq"` e uma segunda regra para `sd[a-z]*\|nvme[0-9]*n[0-9]*\|mmcblk[0-9]*` com `rotational=="0"` → `none` |
| `90-xinguos-journald.conf` | `/usr/lib/systemd/journald.conf.d/90-xinguos.conf` | `[Journal]` / `SystemMaxUse=200M` |
| `90-xinguos-oomd-user.conf` | `/usr/lib/systemd/system/user@.service.d/90-xinguos-oomd.conf` | `[Service]` / `ManagedOOMMemoryPressure=kill` / `ManagedOOMMemoryPressureLimit=50%` (padrão do Fedora) |
| `90-xinguos-oomd-root.conf` | `/usr/lib/systemd/system/-.slice.d/90-xinguos-oomd.conf` | `[Slice]` / `ManagedOOMSwap=kill` |
| `snapper-xinguos` | `/usr/share/snapper/config-templates/xinguos` | copiado do template `default` do snapper, com `NUMBER_LIMIT="10"`, `NUMBER_LIMIT_IMPORTANT="5"`, `TIMELINE_CREATE="no"` e `NUMBER_CLEANUP="yes"` |

- **`.install`:**
  - `post_install`:
    - `systemctl enable systemd-oomd.service fstrim.timer NetworkManager.service bluetooth.service`;
    - Flathub: `flatpak remotes --system | grep -q flathub || flatpak remote-add --if-not-exists --system flathub https://dl.flathub.org/repo/flathub.flatpakrepo || echo "xinguos-base: aviso: não consegui adicionar o Flathub agora"`. **Nunca falha.**
  - `post_upgrade`: não faz nada. Não reabilita serviço que o usuário desligou.

- [ ] **Passo 1: escrever os testes em `tests/base.bats`:**
  - `@test "regras de udev são válidas"`: `udevadm verify packages/xinguos/xinguos-base/60-xinguos-ioschedulers.rules` com status 0;
  - `@test "valores do spec 7.1"`: greps exatos de `zram-size = ram / 2`, `compression-algorithm = zstd`, `vm.swappiness = 180`, `vm.page-cluster = 0`, `SystemMaxUse=200M`, `NUMBER_LIMIT="10"`;
  - `@test "xinguos-base não depende de kernel nem de cups"`: o `depends` do PKGBUILD (via `source PKGBUILD; printf '%s\n' "${depends[@]}"`) não contém `linux-zen`, `linux-lts` nem `cups`;
  - `@test "configs vão para diretórios de fornecedor"`: nenhum `install ... "$pkgdir/etc/` no PKGBUILD;
  - `@test ".install não falha sem rede"`: rode o `post_install` com stubs de `systemctl` e de `flatpak` (o `remote-add` sai com 1) no PATH; status 0 e a saída contém `aviso: não consegui adicionar o Flathub`.
- [ ] **Passo 2: push.** Esperado: **FALHA**.
- [ ] **Passo 3: criar os arquivos e os dois PKGBUILDs.** Acrescente ao `ordem.txt`.
- [ ] **Passo 4: push.** Esperado: `testes` verde. Depois rode o workflow com dispatch: `build` verde com os dois pacotes na release.
- [ ] **Passo 5: commit** — `feat(base): xinguos-base (desempenho, serviços, snapshots) e xinguos-kernels`

### Task 7: smoke instala de verdade

**Arquivos:**
- Modificar: `tests/smoke-repo.sh`

**Interfaces:**
- Depois do que o smoke já faz, acrescentar:
  1. `pacman -S --noconfirm xinguos-hwdetect` e `xinguos-hwdetect --detectar`. O container não tem GPU, então a saída precisa conter `perfil=desconhecida`;
  2. `pacman -Sw --noconfirm xinguos-base xinguos-kernels`, que baixa **toda a árvore de dependências** e verifica as assinaturas. Prova que tudo resolve com os repos oficiais + `[xinguos]`, sem AUR;
  3. `test -f /usr/share/libalpm/hooks/10-xinguos-nvidia-guard.hook`.

- [ ] **Passo 1: escrever as três verificações no smoke.** Elas são o teste desta task. Os pacotes já estão na release desde as Tasks 4 a 6, então o teste roda contra pacotes reais.
- [ ] **Passo 2:** rode `gh workflow run repo.yml --ref plano2`. Esperado: `smoke` verde, com `perfil=desconhecida` no log.
- [ ] **Passo 3: commit** — `test(ci): smoke instala xinguos-hwdetect e resolve xinguos-base`

### Task 8: ISO de teste com a base nova

**Arquivos:**
- Modificar: `iso/teste/pacotes.txt` (acrescentar `xinguos-base` e `xinguos-hwdetect`, **sem** `xinguos-kernels`, porque a ISO boota o `linux`), `tests/build-iso.bats`

- [ ] **Passo 1: teste:** `@test "ISO leva xinguos-base e xinguos-hwdetect, mas não os kernels extras"` (greps no `packages.x86_64` do perfil).
- [ ] **Passo 2: push** (**FALHA**) → acrescentar os pacotes → **push** (verde).
- [ ] **Passo 3:** rode `gh workflow run repo.yml --ref plano2 -f iso=true`. Esperado: `iso-teste` verde. Baixe com `gh run download`, rode `sha256sum -c` e mova para `D:\isos\Linux\xinguos-teste.iso`, substituindo a anterior.
- [ ] **Passo 4: commit** — `feat(iso): ISO de teste com xinguos-base e xinguos-hwdetect`

### Task 9: [MANUAL — Xingu] conferir a base no live

Boote a ISO nova pelo modo do Ventoy que funcionou e rode no Konsole:

| Comando | Esperado |
|---|---|
| `zramctl` | um `/dev/zram0` com uns 6 G, `zstd` |
| `sysctl vm.swappiness vm.page-cluster` | `180` e `0` |
| `cat /sys/block/sd*/queue/scheduler` | `[bfq]` no HD do Ventoy; `[none]` no SSD |
| `systemctl is-active systemd-oomd fstrim.timer` | `active` e `active` |
| `xinguos-hwdetect --detectar` | `perfil=nvidia-580xx`. Se vier `varias`, a iGPU Intel está ligada na BIOS (anote) |
| `sudo pacman -S nvidia-open-dkms` | **cancelado** pelo `xinguos-nvidia-guard`, com a mensagem |

Anote em `marco0/resultados.md`, numa seção nova "Plano 2 no live", e faça o commit.
