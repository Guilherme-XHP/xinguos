# XInguOS — Plano 6: branding, boas-vindas e ISO de instalação (Calamares)

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:executing-plans. Steps use checkbox (`- [ ]`) syntax.

**Objetivo:** uma ISO `xinguos.iso` que boota ao vivo com o visual do XInguOS e instala o sistema no disco pelo Calamares (Btrfs + GRUB + snapper). No primeiro login abre o app "Bem-vindo ao XInguOS". A foto do cachorro aparece como easter egg.

**Spec:** `docs/superpowers/specs/2026-11-08-xinguos-design.md` (2.1, 5.1–5.4, 8.2, 9, 10.3, 12).

**Branch:** `plano6`, a partir do `main` (Planos 1, 2, 4 e 5 já mergeados).

**Execução:** o Xingu delegou tudo ("pode continuar até o gaming mode"). O executor segue sem esperar e registra as decisões no ledger e no spec.

## Restrições globais

- As mesmas dos planos anteriores:
  - shellcheck limpo, LF, commits em PT com `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`;
  - o CI é o ambiente de teste. Python puro pode rodar o pytest local, mas o D-Bus e o Qt só no CI;
  - **mudou o conteúdo de um pacote publicado → sobe o `pkgrel`**.
- O código Python de cada app fica dentro da pasta do pacote, que usa `$startdir`, como o `xinguos-foco`.
- **Segurança do disco (inegociável):** no live, o disco de onde a ISO bootou (Ventoy) é marcado como **somente leitura** antes do SDDM subir. Assim, o instalador não consegue apagá-lo nem por engano.
- **A ISO de instalação não leva o `xinguos-apps`** (vários GB). O app de boas-vindas oferece instalar o `xinguos-apps` depois, marcado por padrão.
- O live mantém o driver 580xx, igual à ISO de teste que funcionou no PC do Xingu. Na instalação, o hwdetect decide: se o perfil não for `nvidia-580xx`, os pacotes 580xx são removidos do sistema instalado.

## Decisões do executor (registradas também no spec 5.x quando a Task terminar)

- **Base do perfil:** `baseline` + overlay, o mesmo `tools/build-iso.sh`, que ganha os parâmetros nome/rótulo. Não é o `releng`, porque o `baseline` já bootou no Ventoy do Xingu.
- **Instalação offline:** o `unpackfs` copia o `airootfs.sfs` do live. Um script `pos-instalacao`, testado no CI num chroot, desfaz o que é só do live.
- **O Plymouth fica para o branding final** (9: "provisório"). Entram nesta versão `os-release`, logo, wallpaper, cor de destaque, SDDM Breeze com o wallpaper, `GRUB_DISTRIBUTOR` e a página "Sobre o sistema".
- **Easter egg:** a logo do app de boas-vindas, clicada 7 vezes, abre a foto do cachorro ("O verdadeiro dono do XInguOS"). A foto fica em `/usr/share/xinguos/easter-egg/cachorro.jpg`.

---

### Task 1: `xinguos-branding`

**Arquivos:** `packages/xinguos/xinguos-branding/`, com:
- `PKGBUILD`;
- `xinguos-os-release.hook` + `xinguos-os-release` (script);
- `logo/xinguos.svg`;
- `wallpaper/XInguOS/metadata.json` + `contents/images/1920x1080.svg`;
- `kcm-about-distrorc`;
- `easter-egg/cachorro.jpg` (cópia de `branding/easter-egg/cachorro.jpg`);
- `sddm/theme.conf.user` (Breeze com o wallpaper).

Testes em `tests/branding.bats`.

**Interface:**
- **`os-release`:** o `filesystem` é dono de `/etc/os-release` (link para `/usr/lib/os-release`).
  - Um hook do pacman (`PostTransaction`, `Target = filesystem` e `Target = xinguos-branding`) roda `/usr/lib/xinguos/xinguos-os-release`.
  - O script troca o link de `/etc/os-release` por um arquivo com `NAME="XInguOS"`, `PRETTY_NAME="XInguOS"`, `ID=xinguos`, `ID_LIKE=arch`, `BUILD_ID=rolling`, `ANSI_COLOR="38;2;46;196;182"`, `HOME_URL=https://github.com/Guilherme-XHP/xinguos`, `LOGO=xinguos`.
  - O script aceita `--raiz <dir>` para teste.
- **Logo:** SVG simples (letra "X" estilizada no círculo turquesa `#2ec4b6`). Vai para `/usr/share/pixmaps/xinguos.svg` e `/usr/share/icons/hicolor/scalable/apps/xinguos.svg`.
- **Wallpaper:** pacote de wallpaper do Plasma `XInguOS` (gradiente escuro + logo), em `/usr/share/wallpapers/XInguOS/`.
- **`/etc/xdg/kcm-about-distrorc`:** `[General] LogoPath=/usr/share/pixmaps/xinguos.svg`, `Website=https://github.com/Guilherme-XHP/xinguos`, `Variant=Rolling`.
- **SDDM:** `/usr/share/sddm/themes/breeze/theme.conf.user` com `background=/usr/share/wallpapers/XInguOS/contents/images/1920x1080.svg`, mais `/etc/sddm.conf.d/10-xinguos-tema.conf` com `[Theme] Current=breeze`.
- **`depends=(filesystem)`**.

**Testes:**
- `os-release`: gerado com `--raiz` traz `ID=xinguos` e `ID_LIKE=arch`, e troca o link por arquivo;
- o hook aponta para o script e tem os dois Targets;
- o metadata.json do wallpaper é JSON válido, e os SVGs são XML válido (`python3 -c 'import xml.dom.minidom…'`);
- a foto do easter egg é igual à de `branding/` (sha256).

- [ ] RED → implementar → GREEN → commit `feat(branding): xinguos-branding (os-release, logo, wallpaper, SDDM, easter egg)`.

### Task 2: desktop usa o branding

**Arquivos:** `packages/xinguos/xinguos-desktop/` (`PKGBUILD` pkgrel 5 com `depends += xinguos-branding`, `etc-xdg/kdeglobals`, layout.js), `tests/desktop.bats`.

- `kdeglobals` ganha `[General] AccentColor=46,196,182`.
- O `layout.js` põe o wallpaper `/usr/share/wallpapers/XInguOS` em toda área de trabalho (`desktops()[i].wallpaperPlugin = "org.kde.image"`, `currentConfigGroup = ["Wallpaper","org.kde.image","General"]`, `writeConfig("Image", "file:///usr/share/wallpapers/XInguOS")`). O ícone do launcher passa a ser `xinguos`.

**Testes:** `desktop.bats` exige AccentColor, wallpaper e ícone, e que o desktop dependa do branding.

- [ ] RED → GREEN → commit `feat(desktop): cor de destaque, wallpaper e ícone do XInguOS`.

### Task 3: `xinguos-boasvindas` — lógica

**Arquivos:** `packages/xinguos/xinguos-boasvindas/xinguos_boasvindas/{__init__,catalogo,roteiro,estado}.py` e `tests/test_*.py`.

**Interface:**
```python
# catalogo.py
@dataclass(frozen=True)
class Item:
    id: str; nome: str; descricao: str; marcado: bool; aviso: str = ""
ITENS: list[Item]   # nesta ordem:
#  xinguos-apps (marcado), vesktop, zapzap, spotify, natron (Flathub, marcados),
#  curseforge (marcado: abre a página oficial), claude-code (marcado),
#  claude-desktop (NÃO marcado, aviso "não oficial"), android-sdk (marcado),
#  proton-ge (marcado), impressao (não marcado)

# roteiro.py
def roteiro(ids: list[str]) -> str
    # script bash "set -uo pipefail" que roda cada passo, mostra "==> <nome>",
    # segue mesmo se um falhar e no fim lista o que falhou
    # xinguos-apps → sudo pacman -S --needed --noconfirm xinguos-apps
    # flathub → flatpak install -y --user flathub <app-id> (com remote-add --if-not-exists flathub)
    # curseforge → xdg-open https://www.curseforge.com/download/app
    # claude-code → curl -fsSL https://claude.ai/install.sh | bash
    # claude-desktop → paru -S --needed claude-desktop-bin
    # android-sdk → baixa cmdline-tools da URL fixa em ~/Android/Sdk/cmdline-tools/latest e roda
    #   sdkmanager --licenses + "platform-tools" "build-tools;35.0.0" "platforms;android-35" "ndk;28.1.13356709" "cmake;3.10.2.4988404"
    # proton-ge → API do GitHub (releases/latest de GloriousEggroll/proton-ge-custom),
    #   .tar.gz em ~/.steam/root/compatibilitytools.d/
    # impressao → sudo pacman -S --needed --noconfirm cups cups-pdf print-manager system-config-printer
    #   && sudo systemctl enable --now cups.socket
    # id desconhecido → ValueError

# estado.py
def ja_visto(estado_dir: Path) -> bool; def marcar_visto(estado_dir: Path) -> None   # ~/.local/state/xinguos/boasvindas-v1
def aviso_hw(saida_detectar: str) -> str   # do "aviso=" do xinguos-hwdetect --detectar; "" se não houver
```

**Testes:**
- todo id do catálogo tem passo no roteiro;
- passos na ordem pedida;
- `bash -n` no roteiro gerado (sintaxe);
- id desconhecido → ValueError;
- `claude-desktop` desmarcado e com aviso;
- o roteiro nunca usa `sudo` em passo de usuário (flatpak `--user`, proton, sdk);
- `aviso_hw` vazio e com texto;
- visto/marcar.

- [ ] RED → GREEN → commit `feat(boasvindas): catálogo e roteiro de instalação`.

### Task 4: `xinguos-boasvindas` — janela e pacote

**Arquivos:**
- `xinguos_boasvindas/{__main__.py,Main.qml}`;
- `PKGBUILD`, wrapper `xinguos-boasvindas`;
- `org.xinguos.boasvindas.desktop` (launcher), `xinguos-boasvindas-autostart.desktop` (em `/etc/xdg/autostart`, `Exec=xinguos-boasvindas --primeira-vez`);
- testes: `test_qml_carrega` (offscreen) e `tests/boasvindas.bats`.

**Comportamento:**
- Com `--primeira-vez`, sai na hora se já foi visto.
- A janela tem:
  - logo (7 cliques abrem o cachorro);
  - texto de boas-vindas e aviso de hardware, se houver;
  - lista de caixinhas do catálogo;
  - "Mostrar ao iniciar" (desmarcar grava como visto);
  - botão "Instalar selecionados", que grava o roteiro em `$XDG_RUNTIME_DIR/xinguos-boasvindas.sh` e abre `konsole --hold -e bash <arquivo>`.
- Seções "Sessão padrão" e "Gaming Mode" ficam para o Plano 3.
- Pacote: `depends=(python pyside6 konsole flatpak curl xinguos-branding)`; `xinguos-desktop` pkgrel 6 passa a depender de `xinguos-boasvindas`.

- [ ] RED → GREEN → commit `feat(boasvindas): app Bem-vindo ao XInguOS`.

### Task 5: Calamares no `[xinguos]`

- Copiar do AUR com `tools/sync-aur.sh` e fixar o commit em `aur-pins.txt`, se for -git (não é: `calamares` 3.4.x).
- Entra em `ordem.txt` antes do desktop. Dependências do AUR que faltarem entram também.
- Teste: o build compila. O smoke faz `pacman -Sw calamares`.

- [ ] Sincronizar → dispatch → commit `feat(iso): calamares no [xinguos]`.

### Task 6: configuração do Calamares + pós-instalação

**Arquivos:** `iso/instalar/calamares/`, com:
- `settings.conf`;
- `branding/xinguos/{branding.desc,show.qml,logo.svg}`;
- `modules/*.conf`: welcome, locale, keyboard, partition, mount, unpackfs, fstab, users, displaymanager, services-systemd, bootloader, grubcfg, finished, `shellprocess@pos`.

Também `iso/instalar/airootfs/usr/lib/xinguos/instalador/pos-instalacao` e `tests/instalador.bats`.

**Configuração:**
- **welcome:** precisa de 20 GB de disco e 2 GB de RAM; internet é recomendada, não obrigatória.
- **locale:** `pt_BR.UTF-8`, `America/Sao_Paulo`. **keyboard:** `br`, `abnt2`.
- **partition:**
  - `defaultFileSystemType: "btrfs"`, `availableFileSystemTypes: ["btrfs","ext4"]`;
  - `efiSystemPartition: "/boot/efi"`, `userSwapChoices: [none]`, `initialSwapChoice: none`;
  - `drawNestedPartitions: true`, `alwaysShowPartitionLabels: true`.
- **mount:** `btrfsSubvolumes` `@ / @home /home / @snapshots /.snapshots / @log /var/log / @cache /var/cache`, com `mountOptions` btrfs `compress=zstd,noatime`.
- **unpackfs:** `source: /run/archiso/bootmnt/arch/x86_64/airootfs.sfs`, `sourcefs: squashfs`, `destination: ""`.
- **users:** grupos `wheel`, `video`, `audio`, `input`, `gamemode`; `sudoersGroup: wheel`; `setRootPassword: false`.
- **displaymanager:** `sddm`.
- **services-systemd:** NetworkManager, bluetooth, sddm, fstrim.timer, snapper-cleanup.timer, `grub-btrfsd`.
- **bootloader:** `efiBootLoader: grub`, `efiBootloaderId: XInguOS`. **grubcfg:** `GRUB_DISTRIBUTOR=XInguOS`.
- **`shellprocess@pos`:** roda `/usr/lib/xinguos/instalador/pos-instalacao` no chroot, com timeout de 1800 s. Vem antes do `initcpiocfg` e do bootloader na sequência.

**`pos-instalacao [--raiz <dir>]`** (bash, idempotente, sai com 0 só se o essencial deu certo):
1. remove o que é só do live:
   - o usuário de teste `xingu` do live, se nenhum usuário novo tiver esse nome. Atenção: o usuário criado pelo Calamares pode se chamar xingu também, então o live passa a usar o usuário `live`;
   - `/etc/sddm.conf.d/10-xinguos-live.conf`, `/etc/sudoers.d/10-xinguos-live`, o serviço `xinguos-live-usuario` (arquivo e links), o serviço de proteção do disco, `/etc/mkinitcpio.conf.d/archiso.conf`, `/etc/systemd/system/getty@tty1.service.d/autologin.conf`, o atalho do instalador na área de trabalho e o próprio `/usr/lib/xinguos/instalador`;
   - `pacman -Rns --noconfirm calamares mkinitcpio-archiso`, ignorando os que não estiverem instalados;
2. refaz os presets do mkinitcpio de cada kernel em `/usr/lib/modules/*/pkgbase` (template `/usr/share/mkinitcpio/hook.preset`, `%PKGBASE%`), copia `vmlinuz` para `/boot/vmlinuz-<pkgbase>` e roda `mkinitcpio -P`;
3. roda `xinguos-hwdetect --detectar`. Se o perfil não for `nvidia-580xx`, remove `nvidia-580xx-dkms nvidia-580xx-utils lib32-nvidia-580xx-utils`, depois roda `xinguos-hwdetect --apply`, que precisa de internet e só avisa se falhar;
4. `snapper --no-dbus create-config /` com o template `xinguos`. Tudo que falhar só avisa;
5. remove o kernel `linux` do live, se o `linux-zen` estiver presente.

**Testes (`instalador.bats`, no job `testes`, com stubs de pacman/mkinitcpio/snapper/xinguos-hwdetect em `tests/stubs`):**
- numa raiz falsa com os arquivos do live, todos eles somem;
- presets criados para `linux-zen` e `linux-lts` a partir do template, e o `vmlinuz` é copiado;
- perfil `amd` → remove os pacotes 580xx; perfil `nvidia-580xx` → mantém;
- falha do snapper não derruba;
- rodar duas vezes não quebra;
- todos os `.conf` do Calamares são YAML válido (`python3 -c 'import yaml'`, com `python-yaml` no ci-setup);
- o `settings.conf` cita todos os módulos que têm `.conf` e o `shellprocess@pos` vem antes do `bootloader`.

- [ ] RED → GREEN → commit `feat(iso): configuração do Calamares e pós-instalação`.

### Task 7: perfil `iso/instalar` + proteção do disco + teste de instalação no CI

**Arquivos:**
- `iso/instalar/pacotes.txt`: o da ISO de teste + `calamares`, `xinguos-kernels`, `xinguos-branding`, `xinguos-boasvindas`, `grub`, `efibootmgr`, `os-prober`, `btrfs-progs`, `dosfstools`, `mtools`, `python-yaml`;
- `iso/instalar/airootfs/`:
  - `xinguos-live-usuario`: usuário `live`, sem senha, autologin no Plasma;
  - `xinguos-protege-midia.service` + script;
  - atalho do instalador em `/etc/skel/Desktop/` e no launcher (`pkexec calamares` → `sudo -E calamares`);
- `tools/build-iso.sh`:
  - aceita `XINGUOS_ISO_NOME` (padrão `xinguos-teste`);
  - copia `iso/<perfil>/calamares` para `/etc/calamares`;
  - os protótipos do Marco 0 só entram na ISO de teste;
- `tests/build-iso.bats`;
- workflow: input `iso_instalar` (bool) → job `iso-instalar`, que monta `xinguos.iso`, roda o **teste de instalação em chroot** e publica o artifact `xinguos-iso`.

**`xinguos-protege-midia`** (bash, `Before=display-manager.service`):
- acha o disco do boot: a origem de `/run/archiso/bootmnt` e, subindo pelo `lsblk -no PKNAME`, até o disco. Com o Ventoy, a origem é `/dev/mapper/ventoy`, e o `dmsetup deps`/`lsblk -s` leva ao disco físico;
- acha também todo disco que tenha partição com `LABEL=Ventoy` ou `VTOYEFI`;
- roda `blockdev --setro` no disco e nas partições e grava a lista em `/run/xinguos/midia-protegida`;
- aceita `--raiz` e entradas falsas (stubs de `lsblk`/`findmnt`/`blockdev`) para teste.

**Teste de instalação (CI, no job `iso-instalar`, `--privileged`):**
1. `unsquashfs` do `airootfs.sfs` da ISO num diretório;
2. `arch-chroot` nele e roda `pos-instalacao`. Confere:
   - `/boot/vmlinuz-linux-zen` e `/boot/initramfs-linux-zen.img`;
   - o usuário `live` sumiu;
   - não ficou nenhum arquivo do live;
   - `grub-mkconfig -o /tmp/g.cfg` gera entradas para o linux-zen;
   - `pacman -Q calamares` falha.

**Testes bats:**
- proteção: disco do boot e disco com rótulo Ventoy entram; outro disco não;
- `build-iso` com `XINGUOS_ISO_NOME=xinguos` muda nome e rótulo e copia o calamares; a ISO de teste continua igual.

- [ ] RED → GREEN → dispatch `iso_instalar=true` → baixar `xinguos.iso` para `D:\isos\Linux` com `sha256sum -c` → commit `feat(iso): ISO de instalação do XInguOS`.

### Task 8: [MANUAL — Xingu] checklist 10.3 (parte do Plano 6)

| Faça | Esperado |
|---|---|
| Bootar a `xinguos.iso` pelo Ventoy (modo alternativo) | Plasma do live com o wallpaper do XInguOS e o atalho "Instalar o XInguOS" |
| `cat /run/xinguos/midia-protegida` | o HD do Ventoy aparece |
| **Numa VM ou num SSD vazio**, nunca no D:, instalar pelo Calamares com "Apagar disco" | instalação termina; reboot vai para o GRUB "XInguOS" e depois para o SDDM |
| Primeiro login | abre o "Bem-vindo ao XInguOS" |
| Clicar 7 vezes na logo | aparece o cachorro |
