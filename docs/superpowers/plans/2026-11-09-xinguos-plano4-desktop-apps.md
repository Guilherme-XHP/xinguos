# XInguOS — Plano 4: `xinguos-desktop` + `xinguos-apps`

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Objetivo:** o desktop do XInguOS sai pronto do primeiro login, sem o usuário configurar nada:
- barra no topo estilo Mac (launcher + menu global + bandeja + relógio);
- dock flutuante embaixo;
- atalhos do Windows;
- autotile opcional (Win+T);
- Dolphin no estilo Explorer;
- os apps do Xingu.

**Arquitetura:** três peças, cada uma testável:
1. **Global Theme `org.xinguos.desktop`** em `/usr/share/plasma/look-and-feel/`:
   - `contents/layouts/org.kde.plasma.desktop-layout.js` (painéis);
   - `contents/defaults` (tema Breeze).
   - Vira o tema padrão do sistema por `/etc/xdg/kdeglobals` → `[KDE] LookAndFeelPackage=org.xinguos.desktop`. Na primeira vez que o plasmashell sobe sem layout salvo, ele usa o layout desse tema.
2. **`xinguos-primeiro-login`**: um executável chamado por `/etc/xdg/plasma-workspace/env/xinguos-primeiro-login.sh`, que roda **antes** do kglobalaccel e do plasmashell.
   - Uma única vez por usuário (marca em `~/.local/state/xinguos/desktop-v1`), grava com `kwriteconfig6`: atalhos, Krohnkite, Dolphin, Baloo e notificador do Discover.
   - Se o usuário já tinha um layout de painel (conta criada antes do XInguOS), move esse layout para `*.antes-xinguos`, para o plasmashell gerar o do tema.
   - Isso é permitido pela regra 2.4 do spec: escrever em `~/.config` só no primeiro login.
3. **Pacotes meta**: `xinguos-desktop` (Plasma mínimo + o que está acima) e `xinguos-apps` (spec 8.1).

**Stack:** bash, bats, Plasma 6.8 (scripting API de layout), `kwriteconfig6`, Krohnkite (copiado do AUR), PKGBUILD.

**Spec:** `docs/superpowers/specs/2026-11-08-xinguos-design.md` (seções 2.1, 2.4, 6, 8.1). Pré-requisito: Planos 1 e 2.

**Branch:** `plano4`, a partir do `main` depois do merge do `plano2`.

**Execução:** o Xingu delegou a revisão deste plano ("deixar você fazendo o rolê todo"). O executor segue sem esperar aprovação, e o plano vai para o Xingu revisar depois.

## Restrições globais

- Tudo dos Planos 1 e 2:
  - bash `set -euo pipefail`, shellcheck limpo;
  - LF;
  - commits em PT com `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`;
  - o CI é o ambiente de teste;
  - **mudou o conteúdo de um pacote publicado → sobe o `pkgrel`**.
- Pacotes novos: `pkgver=0.1.0`, `pkgrel=1`, `arch=(any)`, `license=(GPL-3.0-or-later)`, `url="https://github.com/Guilherme-XHP/xinguos"`.
- **KDE Connect nunca entra** (spec 2.4). O `xinguos-desktop` não depende do grupo `plasma` nem do `plasma-meta`.
- O script de env é **sourced** pelo `startplasma`. Ele não pode ter `exit` nem falhar: só chama o executável com `|| true`.
- O `xinguos-primeiro-login` **nunca** sobrescreve um arquivo de config que o usuário já tenha mexido depois do primeiro login. Ele roda uma vez por versão de marca.

## Atalhos (spec 6.3) → o que o `xinguos-primeiro-login` grava

Arquivo `kglobalshortcutsrc`. O formato do valor é `atalho,padrão,descrição`, e `none` desliga.

| Grupo | Chave | Valor |
|---|---|---|
| `kwin` | `Window Maximize` | `Meta+Up,Meta+PgUp,Maximizar janela` |
| `kwin` | `Window Minimize` | `Meta+Down,Meta+PgDown,Minimizar janela` |
| `kwin` | `Window Quick Tile Left` | `Meta+Left,Meta+Left,Encaixar à esquerda` |
| `kwin` | `Window Quick Tile Right` | `Meta+Right,Meta+Right,Encaixar à direita` |
| `kwin` | `Overview` | `Meta+Tab,Meta+W,Visão geral` |
| `kwin` | `KrohnkiteNextLayout` | `Meta+T,Meta+\\,Krohnkite: alternar flutuante/lado a lado` |
| `kwin` | `KrohnkiteToggleFloat` | `Meta+F,Meta+F,Krohnkite: flutuar janela` |
| `kwin` | `KrohnkiteTileLayout`, `KrohnkiteMonocleLayout`, `KrohnkiteFocusRight` (Meta+L), `KrohnkiteFocusLeft`, `KrohnkiteFocusUp`, `KrohnkiteFocusDown`, `KrohnkiteDecrease` (Meta+D), `KrohnkiteIncrease` (Meta+I), `KrohnkiteRotate` (Meta+R), `KrohnkiteFocusNext` (Meta+.), `KrohnkiteFocusPrev` (Meta+,) | `none,<padrão do krohnkite>,<nome>` (não brigam com os atalhos do Windows) |
| `services` → `org.kde.krunner.desktop` | `_launch` | `Meta+R\tAlt+Space\tAlt+F2` (tabs) |
| `services` → `systemsettings.desktop` | `_launch` | `Meta+I` |
| `services` → `org.kde.plasma-systemmonitor.desktop` | `_launch` | `Ctrl+Shift+Esc` |

Já são padrão do Plasma 6 e **não** são regravados: Win (launcher), Win+E (Dolphin), Win+D, Win+L, Win+V, Win+Shift+S, Win+. (emoji), Win+1…9, Win+Shift+setas, Alt+F4, Alt+Tab. O Win+Shift+G (Gaming Mode) fica para o Plano 3.

## Foco da revisão

1. **Usuário que já usava o Plasma antes do XInguOS** (conta criada no archinstall): o layout antigo vai para `.antes-xinguos` e o novo aparece. Nada é apagado (teste na Task 4).
2. **Rodar o primeiro login de novo** (2º boot, ou `xinguos-desktop` atualizado sem subir a versão da marca) não pode regravar nada que o usuário mudou (teste na Task 4).
3. **Falha do `kwriteconfig6` ou HOME estranho** nunca impede o login: o env script sempre termina com sucesso (teste na Task 4).
4. **A árvore de dependências do `xinguos-desktop` não pode puxar `kdeconnect`** nem `plasma-meta` (teste na Task 6).
5. **Atalho do Krohnkite brigando com atalho do Windows**: Meta+L, Meta+D, Meta+I, Meta+R e Meta+. precisam estar `none` no Krohnkite (teste na Task 4).

---

### Task 1: Krohnkite no `[xinguos]`

- [ ] Rode `tools/sync-aur.sh kwin-scripts-krohnkite` e **leia o PKGBUILD**. Ele precisa baixar uma release versionada (não `-git`) com checksum. Registre no ledger.
- [ ] Acrescente `aur/kwin-scripts-krohnkite` ao `ordem.txt`, rode o dispatch e confira na release: `kwin-scripts-krohnkite-0.9.9.2-4-any.pkg.tar.zst` (ou a versão do PKGBUILD).
- [ ] Commit: `feat(aur): Krohnkite no [xinguos]`.

### Task 2: Global Theme `org.xinguos.desktop`

**Arquivos** (em `packages/xinguos/xinguos-desktop/look-and-feel/org.xinguos.desktop/`):
- `metadata.json`: `KPlugin.Id = "org.xinguos.desktop"`, `Name = "XInguOS"`, `X-Plasma-APIVersion = "2"`, `KPackageStructure = "Plasma/LookAndFeel"`.
- `contents/defaults`, copiado do Breeze:
  - `[kdeglobals][KDE] widgetStyle=Breeze`;
  - `[kdeglobals][General] ColorScheme=BreezeLight`;
  - `[kdeglobals][Icons] Theme=breeze`;
  - `[plasmarc][Theme] name=default`;
  - `[kwinrc][org.kde.kdecoration2] library=org.kde.breeze`.
- `contents/layouts/org.kde.plasma.desktop-layout.js`.
- Teste: `tests/desktop.bats`.

**O que o layout.js cria:**
- **Painel de cima:**
  - `location = "top"`, `height = 28`, `floating = false`, `lengthMode = "fill"`;
  - widgets em ordem:
    1. `org.kde.plasma.kickoff`, com ícone `start-here-kde-plasma` (o logo do XInguOS entra no Plano 6);
    2. `org.kde.plasma.appmenu`;
    3. `org.kde.plasma.panelspacer`;
    4. `org.kde.plasma.systemtray`;
    5. `org.kde.plasma.digitalclock`.
- **Dock embaixo:**
  - `location = "bottom"`, `height = 52`, `floating = true`, `lengthMode = "fit"`, `alignment = "center"`, `hiding = "dodgewindows"`;
  - um único widget, `org.kde.plasma.icontasks`, com `launchers` = `applications:org.kde.dolphin.desktop`, `applications:firefox.desktop`, `applications:org.kde.konsole.desktop`, `applications:steam.desktop`, `applications:systemsettings.desktop`.
- **Desktops:** mantém o wallpaper padrão.

**Desvio do spec, registrado no ledger:** o spec pedia "nome do app em foco" na barra de cima. O Plasma não tem widget nativo para isso (só de terceiros). Fica só o menu global, e o nome do app pode entrar com o `xinguos-foco` (Plano 5).

- [ ] **Teste** `@test "layout.js é JS válido e cria os dois painéis com os widgets certos"`:
  - `node --check` no arquivo (instale `nodejs` no `ci-setup.sh`);
  - greps de `location = "top"`, `location = "bottom"`, `"org.kde.plasma.appmenu"`, `"org.kde.plasma.icontasks"`, `hiding = "dodgewindows"` e `lengthMode = "fit"`;
  - o `metadata.json` é JSON válido (`python3 -m json.tool`) com o Id `org.xinguos.desktop`.
- [ ] RED → implementar → GREEN → commit `feat(desktop): Global Theme org.xinguos.desktop (barra de cima + dock)`.

### Task 3: configs de sistema (`/etc/xdg`)

**Arquivos** (em `packages/xinguos/xinguos-desktop/etc-xdg/`):
- `kdeglobals`:
  - `[KDE]`: `LookAndFeelPackage=org.xinguos.desktop`, `AnimationDurationFactor=0.5`, `SingleClick=false`.
- `baloofilerc`: `[Basic Settings]` `Indexing-Enabled=false`.
- `plasma-workspace/env/xinguos-primeiro-login.sh`: **exatamente** `/usr/lib/xinguos/xinguos-primeiro-login || true`.

- [ ] **Teste** `@test "configs de sistema: tema, animação, baloo e env script inofensivo"`:
  - greps exatos nos três arquivos;
  - o env script tem exatamente uma linha útil e não contém `exit`.
- [ ] RED → implementar → GREEN → commit `feat(desktop): padrões de sistema em /etc/xdg`.

### Task 4: `xinguos-primeiro-login`

**Arquivo:** `packages/xinguos/xinguos-desktop/xinguos-primeiro-login`. **Teste:** `tests/desktop.bats`. **Stub:** `tests/stubs/kwriteconfig6`, que registra `"$*"` em `$KWRITE_LOG`.

**Interface:**
- Sem argumentos. Usa `$HOME`.
- Se `$HOME/.local/state/xinguos/desktop-v1` existir, sai com 0 sem fazer nada.
- Senão:
  1. move `$HOME/.config/plasma-org.kde.plasma.desktop-appletsrc` para `...appletsrc.antes-xinguos`, se existir e se o destino ainda não existir;
  2. grava `kdeglobals` `[KDE] LookAndFeelPackage=org.xinguos.desktop` (no nível do usuário);
  3. grava os atalhos da tabela acima;
  4. Krohnkite:
     - `kwinrc` `[Plugins] krohnkiteEnabled=true`;
     - `kwinrc` `[Script-krohnkite]` com `floatingLayoutOrder=1`, `tileLayoutOrder=2` e **0** em `monocleLayoutOrder`, `threeColumnLayoutOrder`, `spiralLayoutOrder`, `quarterLayoutOrder`, `stackedLayoutOrder`, `columnsLayoutOrder`, `spreadLayoutOrder`, `stairLayoutOrder`, `binaryTreeLayoutOrder` e `cascadeLayoutOrder`;
     - `enableColumnsLayout=false`;
     - `ignoreClass` = o padrão do Krohnkite + `,kdenlive,org.kde.kdenlive,blender,natron,gimp,obs,com.obsproject.Studio,steam,gamescope`.
     - Resultado: o layout inicial é o flutuante, ou seja, autotile desligado (spec 6.4), e o Win+T alterna;
  5. Dolphin:
     - `dolphinrc` `[General] EditableUrl=true`, `GlobalViewProps=true`;
     - `$HOME/.local/share/dolphin/view_properties/global/.directory` com `[Dolphin]`, `ViewMode=1` e `Version=4` (modo detalhes);
  6. Baloo: `baloofilerc` `[Basic Settings] Indexing-Enabled=false`;
  7. Discover: `PlasmaDiscoverUpdates` `[Global] RequiredNotificationInterval=86400`;
  8. cria a marca `desktop-v1`.
- Se qualquer `kwriteconfig6` falhar, segue para o próximo, imprime `xinguos-primeiro-login: aviso: <o quê>` e **ainda assim** cria a marca e sai com 0. Isso evita ficar tentando a cada login.

**Testes** (com `HOME=$BATS_TEST_TMPDIR/home` e o stub no PATH):
- `@test "primeira vez grava atalhos, krohnkite, dolphin e marca"`: o log contém `--file kglobalshortcutsrc --group kwin --key Window Maximize Meta+Up,Meta+PgUp,Maximizar janela` (o stub junta os args com espaço; compare com `grep -F`), `KrohnkiteNextLayout`, `floatingLayoutOrder 1`, `tileLayoutOrder 2` e `EditableUrl true`; o `.directory` tem `ViewMode=1`; a marca existe.
- `@test "atalhos do Krohnkite que brigam com os do Windows ficam none"`: para cada um de `KrohnkiteFocusRight`, `KrohnkiteDecrease`, `KrohnkiteIncrease`, `KrohnkiteRotate`, `KrohnkiteFocusNext` e `KrohnkiteTileLayout`, há uma linha no log com essa chave e valor começando em `none,`.
- `@test "segunda vez não faz nada"`: com a marca criada antes, o log fica vazio.
- `@test "layout antigo do usuário vai para .antes-xinguos"`: com um `appletsrc` com conteúdo `velho`, depois de rodar existe `appletsrc.antes-xinguos` com `velho` e não existe mais `appletsrc`.
- `@test "kwriteconfig6 falhando não impede o login"`: um stub que sai com 1 (`KWRITE_STATUS=1`) → status 0, a saída contém `aviso:` e a marca existe.

- [ ] RED → implementar → GREEN → commit `feat(desktop): primeiro login aplica atalhos, autotile, Dolphin e layout`.

### Task 5: pacotes `xinguos-desktop` e `xinguos-apps`

**`packages/xinguos/xinguos-desktop/PKGBUILD`:**
- `depends=(xinguos-base plasma-desktop plasma-workspace kwin sddm plasma-nm plasma-pa kscreen powerdevil bluedevil plasma-systemmonitor xdg-desktop-portal-kde discover breeze breeze-gtk kdeplasma-addons konsole dolphin kate ark gwenview okular spectacle appmenu-gtk-module kwin-scripts-krohnkite)`;
- instala:
  - o Global Theme em `/usr/share/plasma/look-and-feel/org.xinguos.desktop/`;
  - `etc-xdg/*` em `/etc/xdg/` (`kdeglobals`, `baloofilerc`, `plasma-workspace/env/xinguos-primeiro-login.sh`);
  - `xinguos-primeiro-login` em `/usr/lib/xinguos/` (755);
- `backup=(etc/xdg/kdeglobals etc/xdg/baloofilerc)`;
- `.install`: `post_install` roda `systemctl enable sddm.service || true`.

**`packages/xinguos/xinguos-apps/PKGBUILD`:**
- `depends` = a lista da spec 8.1:
  - `firefox firefox-i18n-pt-br telegram-desktop vlc kdenlive obs-studio audacity gimp blender godot code git android-tools python nodejs npm jdk17-openjdk jdk21-openjdk base-devel gcc gdb cmake clang libreoffice-fresh libreoffice-fresh-pt-br qbittorrent 7zip bitwarden obsidian`;
- `optdepends=('photogimp: GIMP com cara de Photoshop')`. O PhotoGIMP fica opcional neste plano: precisa de revisão do PKGBUILD do AUR, e isso é registrado no ledger;
- `.install`: `post_install` roda `archlinux-java set java-21-openjdk || true`, só se `archlinux-java get` estiver vazio.

- Os dois entram no `ordem.txt` **depois** do Krohnkite.

**Testes** (`tests/desktop.bats`):
- `@test "xinguos-desktop não depende de kdeconnect nem de plasma-meta"`: o `depends` não contém `kdeconnect`, `plasma` nem `plasma-meta`;
- `@test "xinguos-apps tem a lista da spec 8.1"`: um loop pelos 30 nomes;
- `@test "env script e primeiro-login vão para os caminhos certos"`: greps no `package()`.

- [ ] RED → implementar → GREEN, depois dispatch: `build` verde, com os dois pacotes na release. Commit: `feat(desktop,apps): pacotes xinguos-desktop e xinguos-apps`.

### Task 6: smoke resolve desktop e apps sem `kdeconnect`

- [ ] No `tests/smoke-repo.sh`, depois do que já existe:
  1. `pacman -Sp --print-format '%n' xinguos-desktop xinguos-apps > /tmp/arvore.txt`, que resolve toda a árvore sem baixar;
  2. `grep -qx plasma-desktop /tmp/arvore.txt`;
  3. `! grep -qx kdeconnect /tmp/arvore.txt`;
  4. `pacman -Sw --noconfirm xinguos-desktop`, que baixa e verifica as assinaturas do desktop. O `xinguos-apps` fica só no `-Sp`, porque baixar LibreOffice + Blender + Godot pesa demais no CI.
- [ ] Dispatch: `smoke` verde. Commit: `test(ci): smoke resolve xinguos-desktop e xinguos-apps sem kdeconnect`.

### Task 7: ISO de teste com o desktop do XInguOS

- [ ] No `iso/teste/pacotes.txt`: acrescente `xinguos-desktop`. **Não** acrescente o `xinguos-apps` (a ISO passaria de 6 GB). Os apps são testados no PC com `sudo pacman -Syu xinguos-apps`, se o Xingu quiser.
- [ ] No `iso/teste/airootfs/etc/sddm.conf.d/10-xinguos-teste.conf`: nada muda (`Session=plasma.desktop`).
- [ ] Teste no `build-iso.bats`: `@test "ISO leva xinguos-desktop"`. RED → GREEN → dispatch com `iso=true` → baixe a ISO para `D:\isos\Linux` e confira com `sha256sum -c`.
- [ ] Commit: `feat(iso): ISO de teste com o desktop do XInguOS`.

### Task 8: [MANUAL — Xingu] conferir o desktop no live

| O que olhar | Esperado |
|---|---|
| Ao entrar | barra fina no topo (launcher à esquerda, relógio e bandeja à direita) e dock flutuante centralizado embaixo, com Dolphin, Firefox, Konsole, Steam e Configurações |
| Abrir o Dolphin | o menu dele aparece na barra de cima (menu global); a lista de arquivos está em modo detalhes |
| Win | abre o launcher |
| Win+R | abre o KRunner |
| Win+E | abre o Dolphin |
| Win+↑ / Win+↓ | maximiza / minimiza |
| Win+← / Win+→ | encaixa nas metades |
| Win+I | abre as Configurações |
| Ctrl+Shift+Esc | abre o Monitor do Sistema |
| Win+Tab | abre a visão geral |
| Abrir 3 janelas e apertar Win+T | elas se organizam lado a lado |
| Win+T de novo | voltam a flutuar |
| Win+F numa janela organizada | ela solta |
| Win+L | bloqueia (não pode mexer no foco do Krohnkite) |

Anote em `marco0/resultados.md`, numa seção nova "Plano 4 no live".
