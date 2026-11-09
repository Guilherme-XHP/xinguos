# XInguOS — Design (v1)

- **Data:** 2026-11-08
- **Status:** aprovado em brainstorm, aguardando revisão do spec
- **Dono:** Xingu

## 1. Objetivo

O XInguOS é a distro pessoal do Xingu, para usar como **sistema principal do dia a dia**. Ele substitui o Windows por completo: sem dual boot, com o Ventoy como pendrive de resgate. É baseado em **Arch Linux puro** (sem CachyOS) e entregue de dois jeitos:

1. **ISO própria**, com visual próprio e instalador gráfico. É o jeito principal.
2. **Repositório pacman `[xinguos]`**: quem já usa Arch puro instala só os pacotes que quiser, sem o branding.

O sistema tem três pilares:

- **Gaming:** Gaming Mode no estilo Steam Deck funcionando de verdade, com "Mudar para a Área de Trabalho" e caminho de volta.
- **Usabilidade:** o PC tem que *parecer* rápido. Nada de travadas, picos de CPU sem motivo ou serviço de fundo comendo RAM. Com o desktop parado, de 0,8 a 1,2 GB de RAM está ok. O desktop mistura atalhos do Windows, barra de topo no estilo Mac e autotile inteligente opcional.
- **Compatibilidade:** funciona no hardware atual (i5 3330 sem AVX2, GTX 1060 6 GB Pascal, 12 GB de DDR3 1333) e também em máquinas mais novas ou com peças misturadas.

### Critérios de sucesso

- O Gaming Mode abre a interface do Steam Deck. "Mudar para a Área de Trabalho" leva ao Plasma, e um ícone ou atalho volta, sem pedir senha.
- Os jogos de Windows rodam via Proton. MangoHud e GameMode funcionam.
- **VR no PC pelo Quest 2 via Steam Link VR + SteamVR** funciona sem configuração manual.
- Win+setas, Win+R, a tecla Win e o resto da tabela da seção 6.3 funcionam desde a instalação.
- O autotile pode ser ligado e desligado e nunca organiza jogos nem os apps da lista de exceções.
- Com o desktop parado, não há processo de fundo usando CPU de forma recorrente: não existe indexador e as checagens de atualização são diárias.
- Um Arch puro com `[xinguos]` adicionado instala `xinguos-gaming` sem precisar do AUR.

### Fora do escopo da v1

- Notebook híbrido (Intel/AMD + NVIDIA), ARM e Secure Boot.
- IA local (o Xingu monta isso depois, por conta própria).
- Dual boot com Windows (o instalador não detecta Windows).
- Cores, logo e ícones definitivos. A v1 usa o visual provisório da seção 9, e a identidade final tem um brainstorm próprio.

## 2. Arquitetura

Tudo no XInguOS é **pacote pacman**. A ISO é só um Arch puro que já vem com esses pacotes e um instalador. Assim existe uma única definição de tudo, e a ISO e o modo "só os programas" nunca divergem.

```
xinguos/                     (monorepo no GitHub)
├── packages/                PKGBUILDs dos pacotes xinguos-* e dos pacotes AUR recompilados
├── foco/                    código-fonte do xinguos-foco (daemon Rust + painel PySide6)
├── iso/                     perfil archiso + config do Calamares
├── docs/                    specs e planos
└── .github/workflows/       CI: compilar pacotes, publicar o repo, montar e testar a ISO
```

### 2.1 Pacotes

| Pacote | Conteúdo |
|---|---|
| `xinguos-base` | `linux-zen` + `linux-zen-headers` (principal), `linux-lts` + headers (reserva), `intel-ucode`/`amd-ucode`, `linux-firmware`, PipeWire (+ pulse/jack), NetworkManager, BlueZ, `zram-generator`, configs de desempenho (seção 7.1), Btrfs + Snapper + `snap-pac` + `grub-btrfs`, `paru`, Flatpak + Flathub |
| `xinguos-hwdetect` | script de detecção de GPU que roda na instalação e por hook do pacman (seção 3) |
| `xinguos-gaming` | `steam`, `gamescope`, `gamescope-session-steam`, sessões e comandos falsos do SteamOS (seção 4), `mangohud` + `lib32-mangohud`, `gamemode` + `lib32-gamemode`, `protonup-qt`, `heroic-games-launcher` |
| `xinguos-desktop` | Plasma **mínimo** (`plasma-desktop`, `kwin`, `sddm`, `plasma-nm`, `plasma-pa`, `powerdevil`, `bluedevil`, `kscreen`, `plasma-systemmonitor`, `xdg-desktop-portal-kde`, `discover` + backend flatpak), apps base do KDE (Konsole, Dolphin, Kate, Ark, Spectacle, Gwenview, Okular, Klipper), Krohnkite, configs padrão (seção 6), `xinguos-foco` |
| `xinguos-apps` | apps pessoais livres (seção 8) |
| `xinguos-boasvindas` | app "Bem-vindo ao XInguOS" do primeiro boot (seção 5.3) |
| `xinguos-branding` | `os-release`, temas do SDDM, Plymouth e GRUB, wallpapers, look-and-feel do Plasma, logo |
| `xinguos` | metapacote que puxa todos os anteriores |

### 2.2 Pacotes do AUR recompilados no `[xinguos]`

`nvidia-580xx-dkms`, `nvidia-580xx-utils`, `lib32-nvidia-580xx-utils` e o resto da família 580xx que for necessária; `gamescope-session-git`, `gamescope-session-steam-git`; `krohnkite`; `paru`; `heroic-games-launcher-bin`; `protonup-qt`; `photogimp`, ou o equivalente empacotado pelo projeto (seção 8).

Ninguém precisa do AUR pra instalar o XInguOS.

### 2.3 Distribuição

- O GitHub Actions compila cada pacote num container `archlinux` limpo.
- Cada pacote passa pelo `namcap` e é assinado com a **chave GPG do XInguOS**. A chave privada fica num secret do GitHub.
- O resultado é publicado como repositório pacman nas **GitHub Releases**.
- Instalação num Arch puro: importar a chave, adicionar `[xinguos]` no `pacman.conf` e rodar `pacman -S xinguos-<o-que-quiser>`.

### 2.4 Regras de projeto

1. **As configurações do XInguOS são só o padrão.** Elas ficam em `/etc/xdg`, `/etc/skel` e `/usr/share` e nunca são escritas em `~/.config` depois do primeiro login. Atualizar o XInguOS nunca apaga uma personalização do usuário.
2. **Base x86-64 genérica**, a padrão do Arch. Nada de pacotes x86-64-v3/v4, porque o i5 3330 não tem AVX2.
3. **KDE Connect nunca entra.** Nenhum pacote do XInguOS depende dele, e o `xinguos-desktop` não puxa o grupo `plasma` inteiro.

## 3. Hardware — `xinguos-hwdetect`

O script roda: (a) no Calamares, durante a instalação; (b) por hook do pacman quando `xinguos-hwdetect` é instalado ou atualizado; (c) manualmente, com `xinguos-hwdetect --apply`.

| GPU detectada (`lspci -nn`, tabela de PCI IDs) | Ação |
|---|---|
| NVIDIA Maxwell / Pascal / Volta (ex.: GTX 1060) | instala `nvidia-580xx-dkms` + `nvidia-580xx-utils` + `lib32-nvidia-580xx-utils`, coloca `nvidia-drm.modeset=1` no kernel e escolhe o Gaming Mode **compatível** (seção 4.4) |
| NVIDIA Turing ou mais nova | instala `nvidia-open-dkms` + `nvidia-utils` + `lib32-nvidia-utils` e escolhe o Gaming Mode **completo** |
| AMD / Intel | Mesa + `vulkan-radeon`/`vulkan-intel` + lib32; Gaming Mode **completo** |
| Mais de uma GPU, ou nenhuma reconhecida | mantém Mesa/modesetting, avisa no app de boas-vindas e não mexe no driver |

**Proteção:** um hook do pacman (`xinguos-nvidia-guard`) **cancela a transação** se, numa GPU Pascal/Maxwell/Volta, alguma operação for remover o 580xx e instalar `nvidia-open` ou `nvidia` 590 ou mais novo. A mensagem explica o motivo.

Contexto: a NVIDIA tirou o Pascal dos drivers 590+. A série 580 legacy recebe patches de segurança até out/2028, e o Arch passou o 580 para o AUR em dez/2025.

## 4. Gaming Mode

### 4.1 Sessões

O SDDM tem duas sessões:

- **XInguOS Gaming:** `gamescope-session-steam`, ou a variante compatível (4.4).
- **XInguOS Desktop:** Plasma no Wayland.

### 4.2 Troca de sessão

- O `xinguos-session-select <gaming|desktop>` também é instalado com o nome `steamos-session-select`. Ele:
  1. escreve a próxima sessão e o autologin em `/etc/sddm.conf.d/zz-xinguos-session.conf`, por meio de um helper root liberado por **regra do polkit**, só para usuários do grupo `wheel` e só para esse comando, sem pedir senha;
  2. encerra a sessão atual;
  3. o SDDM faz login automático na sessão escolhida.
- **Gaming → Desktop:** pelo botão "Mudar para a Área de Trabalho" do Steam, que chama `steamos-session-select plasma`.
- **Desktop → Gaming:** pelo ícone "Voltar ao Gaming Mode" na área de trabalho e no launcher, ou pelo atalho **Win+Shift+G**.
- **No boot:** abre na última sessão usada. Nas configurações (app de boas-vindas ou `xinguos-session-select --default <gaming|desktop|ultima>`) dá pra fixar uma das duas.

### 4.3 Comandos falsos do SteamOS

Os comandos `steamos-update`, `jupiter-biosupdate`, `steamos-select-branch` e `jupiter-initial-firmware-update` (e outros que o Steam chamar no Gaming Mode) são instalados com versões que não fazem nada ou fazem só o mínimo:

- o `steamos-update check` responde "sem atualização" pelo protocolo que o Steam espera;
- o resto retorna sucesso.

Os pacotes que o `gamescope-session-steam` já fornece não são duplicados.

### 4.4 Modos e proteções

- **Gaming Mode completo:** gamescope em modo embutido + Steam com `-gamepadui` + `mangoapp` para o overlay de desempenho.
- **Gaming Mode compatível:** um Plasma Wayland mínimo (sem painéis nem dock) que abre o `steam -gamepadui` em tela cheia. A troca de sessão é a mesma. Perde o overlay e o limitador de FPS do gamescope.
- O `xinguos-hwdetect` escolhe o modo inicial, que pode ser trocado em `/etc/xinguos/gaming.conf` ou no app de boas-vindas.
- **Contador de falhas:** um contador em `/var/lib/xinguos/gaming-failures` sobe quando a sessão Gaming termina com erro em menos de 60 s e zera quando a sessão dura mais que isso. Com **2 falhas seguidas**, o próximo login vai para o Desktop e mostra uma notificação explicando e oferecendo o modo compatível. Nunca existe loop de boot.

### 4.5 Configurações padrão de jogo

- **MangoHud:** preset leve (FPS, frametime, uso e temperatura de CPU/GPU). Liga e desliga com Shift+F12. Fica desativado até ser acionado.
- **GameMode:** integrado ao `xinguos-foco` (seção 7.2). Coloca o governor em `performance` enquanto o jogo roda.
- **Proton-GE:** baixado pelo app de boas-vindas (via ProtonUp-Qt) no primeiro boot.
- **VR:** Steam Link VR (app oficial no Quest) + SteamVR instalado pelo Steam. O WiVRn **não** vem instalado e fica documentado como plano B caso o SteamVR + 1060 falhe no Marco 0.

## 5. Instalação e primeiro boot

### 5.1 ISO

- Perfil `archiso` baseado no `releng`.
- Boota numa sessão ao vivo com Plasma e o visual do XInguOS, com o atalho do Calamares na área de trabalho.
- O modo ao vivo usa driver genérico (modesetting/nouveau). O driver certo entra na instalação, via hwdetect.
- Precisa funcionar pelo **Ventoy** (testado no checklist da seção 10.3).

### 5.2 Calamares

- O ponto de partida é a configuração aberta do Calamares do EndeavourOS, adaptada. Os pacotes vêm só dos repos oficiais do Arch + `[xinguos]`.
- **Particionamento padrão:** apagar o disco e usar **Btrfs** com os subvolumes `@`, `@home`, `@snapshots`, `@log` e `@cache`, montados com `compress=zstd` e `noatime`. Sem swap em disco.
- **Bootloader:** GRUB com `grub-btrfs` (bootar em snapshots). Funciona com UEFI e com BIOS legado.
- **Padrões:** pt_BR, teclado ABNT2, fuso America/Sao_Paulo. Tudo pode ser alterado no instalador.
- Roda o `xinguos-hwdetect` dentro do chroot.
- Habilita o Snapper com uma configuração para `/` (limite de 10 snapshots de atualização) e o `snap-pac`.

### 5.3 App "Bem-vindo ao XInguOS" (`xinguos-boasvindas`)

Abre no primeiro login do Desktop e também pode ser aberto pelo launcher. Feito em PySide6 + QML. O que ele oferece:

- **Apps fora da ISO** (seção 8.2), com caixinhas. Os de Flathub já vêm marcados.
- **Baixar o Proton-GE.**
- **Sessão padrão:** Gaming, Desktop ou a última usada.
- **Gaming Mode:** completo ou compatível.
- **Ligar a impressão:** instala e habilita `cups`.
- Avisos do hwdetect (GPU não reconhecida, etc.).

No modo "só os programas", num Arch puro, ele é aberto à mão.

### 5.4 Atualizações

- É o `pacman -Syu` normal (ou o Discover). O `snap-pac` cria snapshots antes e depois.
- O DKMS recompila o driver NVIDIA a cada kernel novo. O `xinguos-nvidia-guard` protege o Pascal (seção 3).
- O Discover verifica atualizações **uma vez por dia**, sem notificador rodando o tempo todo.

## 6. Desktop (Plasma 6 no Wayland)

### 6.1 Layout

- **Barra no topo (estilo Mac):**
  - à esquerda, o menu do logo XInguOS (Sobre, Configurações, Suspender, Reiniciar, Desligar), o nome do app em foco e o **menu global**;
  - à direita, bandeja, relógio e notificações.
  - O menu global funciona em apps Qt/KDE. Nos apps que não exportam menu (Firefox, Electron, Steam), o menu continua na própria janela.
- **Dock embaixo:** painel do Plasma flutuante e centralizado, com Gerenciador de Tarefas só de ícones, que se esconde quando uma janela encosta nele. Não usa Plank nem processo extra.

### 6.2 Visual e comportamento

- Animações curtas e sem blur pesado.
- **Baloo desligado** (`/etc/xdg/baloofilerc`: `Indexing-Enabled=false`).
- Clique duplo para abrir.

### 6.3 Atalhos (em `/etc/xdg/kglobalshortcutsrc` e `/etc/xdg/kwinrc`)

| Atalho | Ação |
|---|---|
| Win | launcher de apps com busca (Kickoff) |
| Win+R | Executar (KRunner centralizado) |
| Win+setas | encaixar à esquerda/direita, maximizar, restaurar/minimizar |
| Win+Shift+setas | mover a janela para o monitor vizinho |
| Win+E | Dolphin |
| Win+D | mostrar a área de trabalho |
| Win+L | bloquear a tela |
| Win+V | histórico da área de transferência (Klipper) |
| Win+Shift+S | print de região (Spectacle) |
| Win+. | seletor de emoji |
| Win+Tab | visão geral |
| Win+I | Configurações do Sistema |
| Win+1…9 | abrir/ativar o app N do dock |
| Win+T | ligar/desligar o autotile |
| Win+F | janela atual flutuante/organizada |
| Win+Shift+G | voltar ao Gaming Mode |
| Ctrl+Shift+Esc | Gerenciador de Tarefas (Monitor do Sistema) |
| Alt+F4 | fechar a janela |
| Alt+Tab | alternar janelas |

### 6.4 Autotile inteligente (Krohnkite)

- Vem **desligado** por padrão. Win+T alterna, e o estado sobrevive ao reiniciar.
- **Nunca organiza:** janelas em tela cheia, diálogos e janelas transientes, jogos (`steam_app_*`, `gamescope`, janelas do Steam) e a **lista de exceções**. A lista inicial é `kdenlive`, `blender`, `natron`, `gimp` e `obs`.
- **Pergunta ao aprender:**
  - com o autotile ligado, quando abre a janela principal de um app que não está em nenhuma lista, aparece a notificação *"Organizar \<App\> em mosaico? [Sempre] [Nunca]"*;
  - a resposta vai para `~/.config/xinguos/tiling.conf`, e o helper atualiza a lista de ignorados do Krohnkite;
  - **sem resposta, o app fica flutuando** e a pergunta volta na próxima vez.
- Quem faz isso é o próprio script do KWin do `xinguos-foco` (seção 7.2), que já observa as janelas.
- **Plano B**, se o Krohnkite parar de ser mantido: o tiling manual nativo do KWin (sem autotile). Fica documentado e não é implementado na v1.

### 6.5 Dolphin no estilo Explorer

- Modo detalhes, extensões sempre visíveis, abas e clique duplo.
- Barra de endereço editável (Ctrl+L), F2 para renomear e Del para a lixeira.
- Painel lateral com Início, Área de Trabalho, Downloads, Documentos, Imagens, Vídeos, Músicas, discos e mídias removíveis.
- Painel de pré-visualização desligado.

## 7. Desempenho

### 7.1 Ajustes base (em `xinguos-base`)

| Item | Valor |
|---|---|
| zram | `zram-size = ram / 2`, `compression-algorithm = zstd`; `vm.swappiness=180`, `vm.page-cluster=0` |
| OOM | `systemd-oomd` habilitado para user slices |
| Escalonador de I/O | udev: BFQ em discos rotacionais, `none` em NVMe/SSD |
| TRIM | `fstrim.timer` habilitado |
| journald | `SystemMaxUse=200M` |
| Impressão | `cups` desligado por padrão (liga pelo app de boas-vindas) |
| CPU | governor padrão do kernel; `performance` só via GameMode |

### 7.2 `xinguos-foco` — prioridade + Bem-Estar

**Componentes:**

1. **Script do KWin** (`xinguos-foco-kwin`, em JS): manda pelo D-Bus a classe, o PID e o título da janela em foco a cada troca, e também os eventos de abertura de janela, usados pelo tiling da seção 6.4.
2. **Daemon** `xinguos-foco` (Rust, serviço de usuário do systemd, alvo de ~3 MB de RAM):
   - **Prioridade:**
     - descobre a unit (scope `app-*.scope`) do PID em foco;
     - ajusta `CPUWeight`/`IOWeight` com `systemctl --user set-property --runtime`, usando a delegação de cgroups do usuário. **Não precisa de root.**
     - Pesos: app em foco = 500; lista **"Sempre prioridade"** = 1000; normal = 100; lista **"Segundo plano"** = 25.
     - O peso volta ao normal quando o app sai de foco, exceto para quem está nas listas.
   - **GameMode:** quando um jogo (`steam_app_*`) está em foco, o daemon garante peso 1000 e deixa o resto para o GameMode.
   - **Bem-Estar:**
     - soma o tempo de foco de cada app em `~/.local/share/xinguos/foco.db` (SQLite);
     - pausa depois de 2 min sem atividade (via `org.freedesktop.ScreenSaver` / KIdleTime);
     - com limite diário configurado, manda uma notificação ao atingir o limite e não bloqueia nada.
   - **Tiling:** guarda as listas "Sempre/Nunca" e manda a pergunta da seção 6.4.
3. **Painel** `xinguos-foco-painel` (PySide6 + QML): gráfico de uso do dia e da semana por app, edição das listas de prioridade e dos limites diários.

**Config:** `~/.config/xinguos/foco.toml` (listas e limites). O padrão vem em `/etc/xdg/xinguos/foco.toml`.

**Falhas:**
- o systemd reinicia o daemon (`Restart=on-failure`);
- sem o script do KWin, ou com o D-Bus fora, o sistema funciona normal, só sem prioridade e sem estatística;
- se o banco estiver corrompido, ele é renomeado para `foco.db.corrompido-<data>` e um novo é criado.

O Gaming Mode não entra no Bem-Estar, porque o Steam já registra as horas de jogo.

#### 7.2.1 Decisões delegadas (2026-11-09)

O Xingu delegou o design do painel ("deixar você fazendo o rolê todo"). Estas escolhas valem até ele revisar:

- **Painel "Foco"** (PySide6 + QML, abre pelo launcher como "Foco: tempo de uso e prioridades"):
  - **sem ícone na bandeja**: o painel só existe quando está aberto, então não gasta RAM parado;
  - três abas:
    1. **Hoje:** tempo total de tela e uma barra horizontal por app (ícone + nome do `.desktop` + tempo), do maior para o menor;
    2. **Semana:** uma coluna por dia com o total, e ao clicar no dia aparecem os apps dele;
    3. **Prioridades e limites:** lista dos apps já vistos, cada um com um seletor `Sempre prioridade / Normal / Segundo plano` e um campo opcional "limite diário (min)". Salva direto no `foco.toml`, e o daemon recarrega sozinho.
- **Identificação do app:** o `desktopFileName` da janela, que o KWin informa. Se vier vazio, usa o `resourceClass`. Nome e ícone saem do `.desktop`.
- **Dados:** SQLite com uma tabela de intervalos (`app`, `inicio`, `fim`, em segundos Unix), guardados por **90 dias**.
- **Ociosidade:** o daemon consulta `org.freedesktop.ScreenSaver.GetSessionIdleTime` a cada 30 s. Com mais de 120 s parado, fecha o intervalo atual.
- **Avisos:** limite diário e a pergunta do autotile (6.4) usam `org.freedesktop.Notifications`, com botões de ação. Quem faz é o próprio daemon, sem Python.
- **Prioridade:** como na 7.2, via `CPUWeight`/`IOWeight` no `app-*.scope` do app em foco. Jogos lançados pelo Steam herdam o scope do Steam, então o Steam inteiro ganha peso enquanto o jogo está em foco.
- **Ficam para depois (YAGNI):** widget na barra mostrando o app em foco; bloquear o app quando o limite estoura (o spec diz que só avisa); exportar dados.
- **Daemon em Python, não em Rust** (muda a 7.2):
  - Binário compilado muda de bytes quando a toolchain do Arch atualiza, e a trava de conteúdo do repositório (Plano 2) passaria a falhar o CI sem mudança real.
  - Não há Rust na máquina do Xingu para gerar o `Cargo.lock`.
  - Python (`asyncio` + `python-dbus-fast` + `sqlite3` + `tomllib`) é reprodutível e testável com pytest.
  - Custo: ~25 MB de RAM em vez de ~3 MB.
- **Sem a pergunta "Organizar X em mosaico?"** (muda a 6.4):
  - O KWin e o Krohnkite não informam se o autotile está ligado, então o daemon não teria como perguntar só nessa hora.
  - No lugar dela, a aba "Prioridades e limites" ganha uma coluna **Autotile (sim/não)** por app. "Não" acrescenta o app ao `ignoreClass` do Krohnkite, e vale a partir do próximo login.
  - O estado do Win+T **não** sobrevive ao reiniciar: o Krohnkite volta para o layout flutuante.
- **I/O por usuário:** o `xinguos-base` passa a delegar o controlador `io` para o `user@.service` (`Delegate=cpu cpuset io memory pids`). Sem isso, o `IOWeight` nos apps do usuário é ignorado.

## 8. Apps

### 8.1 Dentro da ISO (`xinguos-apps`, repos oficiais + `[xinguos]`)

| Categoria | Pacotes |
|---|---|
| Navegador | `firefox` (+ `firefox-i18n-pt-br`) |
| Comunicação | `telegram-desktop` |
| Mídia | `vlc`, `kdenlive`, `obs-studio`, `audacity`, `gimp` + PhotoGIMP |
| 3D/VFX | `blender` |
| Dev | `godot`, `code` (Code-OSS, com Open VSX), `git`, `android-tools`, `python`, `nodejs` + `npm`, `jdk17-openjdk` (exportar do Godot pro Android/Quest), `jdk21-openjdk` (Minecraft), `base-devel`, `gcc`, `gdb`, `cmake`, `clang` |
| Escritório | `libreoffice-fresh` + `libreoffice-fresh-pt-br` |
| Utilitários | `qbittorrent`, `7zip`, `bitwarden`, `obsidian` |

O JDK padrão (`archlinux-java`) é o 21. O Android SDK completo (build-tools, platform, NDK) é instalado pelo app de boas-vindas, porque é grande e depende da versão do Godot.

### 8.2 Fora da ISO (app de boas-vindas)

| App | Fonte | Marcado por padrão |
|---|---|---|
| Vesktop (Discord) | Flathub `dev.vencord.Vesktop` | sim |
| ZapZap (WhatsApp) | Flathub `com.rtosta.zapzap` | sim |
| Spotify | Flathub `com.spotify.Client` | sim |
| Natron | Flathub `fr.natron.Natron` | sim |
| CurseForge | AppImage oficial da Overwolf | sim |
| Claude Code | instalador oficial da Anthropic | sim |
| Claude Desktop | pacote não oficial da comunidade (se ainda não existir versão oficial) | não, com aviso |
| Android SDK para Godot | `sdkmanager` | sim |

## 9. Branding provisório (v1)

- Tema Breeze com uma cor de destaque do XInguOS.
- Logo e wallpaper provisórios.
- Tema do SDDM baseado no Breeze, Plymouth com o logo e tema do GRUB.
- `os-release` com `NAME="XInguOS"`, `ID=xinguos` e `ID_LIKE=arch`.

**Easter egg obrigatório:** a foto do cachorro do Xingu (`branding/easter-egg/cachorro.jpg`, sem metadados, só com a etiqueta de orientação) precisa aparecer em algum lugar da distro, como piada interna. Onde e como aparece é decidido no brainstorm de branding.

A identidade visual final (cores, logo, ícones, wallpapers) tem um brainstorm próprio depois da v1.

## 10. Testes

### 10.1 Marco 0 — viabilidade no hardware real (bloqueia o resto)

Feito num pendrive com Arch puro via Ventoy, ou numa instalação Arch de teste, no PC do Xingu:

1. `nvidia-580xx-dkms` instalado: Plasma Wayland estável.
2. `gamescope -e -- steam -gamepadui` a partir de uma TTY. Conferir se aparece o bug de **tela preta quando o cursor some**, relatado em GTX 1000. **O resultado define o modo padrão da 1060:** completo ou compatível.
3. `gamescope-session-steam` + "Mudar para a Área de Trabalho" funcionando com um protótipo do `steamos-session-select`.
4. Steam Link VR + SteamVR com o Quest 2 rodando Half-Life: Alyx.
5. Menu global com Kdenlive, Dolphin e um app GTK.

Cada item é registrado como ok, ok com ajuste ou falhou, junto com o plano B usado.

### 10.2 CI (GitHub Actions)

- Cada pacote é compilado em chroot limpo, com `namcap` sem erros.
- Testes automatizados do `xinguos-foco` (`cargo test`): mapeamento PID→scope, cálculo de pesos, contagem de tempo com ociosidade e recuperação de banco corrompido.
- Testes do `xinguos-hwdetect` com saídas de `lspci` gravadas: Pascal, Turing, AMD, Intel, múltiplas GPUs e desconhecida.
- Testes do contador de falhas do Gaming Mode.
- Montagem da ISO e **boot automático no QEMU** (sem tela), conferindo se chega no `graphical.target` / SDDM.

### 10.3 Checklist manual antes de cada versão da ISO

- Boot pelo Ventoy, instalação pelo Calamares (UEFI e BIOS legado) e primeiro boot com o app de boas-vindas.
- Troca Gaming ↔ Desktop 3 vezes seguidas.
- Atualização com snapshot seguida de boot num snapshot pelo GRUB.
- Os atalhos da seção 6.3.
- Autotile: liga/desliga, exceções e pergunta.
- Um jogo via Proton com MangoHud, e uma sessão de VR.
- Desktop parado por 5 minutos: confirmar no `top` que não há pico recorrente de CPU.

## 11. Ordem de construção

1. **Marco 0** (10.1).
2. **Infra:** monorepo no GitHub, chave GPG, CI que compila e publica o `[xinguos]`.
3. **`xinguos-base`, `xinguos-hwdetect`, `xinguos-gaming`.** A partir daqui o Xingu instala um Arch puro (`archinstall`) + `[xinguos]` e passa a usar no dia a dia.
4. **`xinguos-desktop`** (layout, atalhos, Dolphin, Krohnkite) + **`xinguos-apps`**.
5. **`xinguos-foco`** (prioridade, Bem-Estar, pergunta do tiling).
6. **ISO + Calamares + `xinguos-boasvindas`** + `xinguos-branding` provisório.
7. Brainstorm e polimento do branding final.

Cada etapa a partir da 2 tem seu próprio plano de implementação.

## 12. Riscos e pontos a verificar

| Risco | Impacto | Mitigação |
|---|---|---|
| Gamescope com tela preta na GTX 1060 | Gaming Mode completo inviável | Gaming Mode compatível (4.4), definido no Marco 0 |
| Driver 580xx sai do ar ou quebra com kernel novo | sem vídeo acelerado | `linux-lts` de reserva, snapshots, `xinguos-nvidia-guard`; patches de segurança até out/2028 |
| SteamVR no Linux + NVIDIA instável | VR ruim | WiVRn como plano B documentado |
| Krohnkite abandonado | sem autotile | tiling nativo do KWin (sem autotile) |
| Menu global limitado (GTK/Electron/Firefox) | barra de topo incompleta | aceito: o menu fica na janela |
| Claude Desktop sem versão oficial pra Linux | app indisponível | opcional e desmarcado, com aviso |
| CurseForge Linux (AppImage) muda ou some | instalador do boas-vindas falha | o boas-vindas mostra o erro e o link da página oficial |
| Calamares trabalhoso de configurar | atraso da ISO | a ISO é a última etapa; até lá, `archinstall` + `[xinguos]` |

**A verificar durante a implementação**, sem bloquear o design:

- versão atual e nomes exatos dos pacotes 580xx no AUR;
- se o `vesktop` está nos repos oficiais (se estiver, sai do Flathub e entra no 8.1);
- os pacotes de PhotoGIMP disponíveis;
- o protocolo exato que o Steam espera do `steamos-update`.
