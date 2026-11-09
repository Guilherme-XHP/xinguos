# XInguOS — Plano 3: Gaming Mode (`xinguos-gaming`)

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:executing-plans. Steps use checkbox (`- [ ]`) syntax.

**Objetivo:**
- Um login "XInguOS Gaming" no estilo Steam Deck, com dois modos:
  - **completo:** `gamescope-session-plus steam`;
  - **compatível:** KWin sozinho + `steam -gamepadui`.
- Troca Gaming ↔ Desktop sem senha:
  - Gaming → Desktop pelo botão "Mudar para a Área de Trabalho" do Steam;
  - Desktop → Gaming por Win+Shift+G ou pelo atalho "Voltar ao Gaming Mode".
- Contador de falhas: nunca deixa o boot em loop.
- Pacote `xinguos-gaming` e metapacote `xinguos`.

**Spec:** `docs/superpowers/specs/2026-11-08-xinguos-design.md`, seções 4.1–4.5, 3, 5.3 e 7.2 (peso dos jogos).

**Branch:** `plano3`, a partir do `main` com o Plano 6 mergeado.

**Execução:** o Xingu delegou tudo ("pode continuar até o gaming mode"). O teste 2 do Marco 0 (gamescope com tela preta na GTX 1060) **não foi feito**.

**Decisão:** a GTX 1060 começa no modo **compatível**, que é o que o hwdetect já grava para o perfil `nvidia-580xx`. O modo completo fica a uma linha de `/etc/xinguos/gaming.conf`, ou a um clique no app de boas-vindas.

## Restrições globais

- As mesmas dos planos anteriores: shellcheck, LF, commits em PT, CI como ambiente de teste, **subir o pkgrel quando o conteúdo mudar**.
- Os scripts aceitam caminhos por variável de ambiente para teste: `XINGUOS_SDDM_DIR`, `XINGUOS_ETC`, `XINGUOS_ESTADO`, `XINGUOS_SESSOES`.
- **Nada de senha na troca:** o helper root é liberado por **regra do polkit** só para quem está no `wheel`, ativo e local, e só para o helper (spec 4.2).
- **Nunca loop:** com 2 falhas seguidas do Gaming (saída ≠ 0 em menos de 60 s), o próximo login vai para o Desktop.

## Peças

| Arquivo (instalado) | Papel |
|---|---|
| `/usr/bin/xinguos-session-select` | `gaming` / `desktop` / `plasma` / `gamescope` / `--default <gaming\|desktop\|ultima>` / `--modo <completo\|compativel>` / `--status` |
| `/usr/lib/os-session-select` | gancho do `steamos-session-select` do gamescope-session-steam: `exec xinguos-session-select "$@"` |
| `/usr/lib/xinguos/xinguos-sessao-root` | helper root via `pkexec`: `sessao <usuario> <sessao.desktop>`, `padrao <gaming\|desktop\|ultima>`, `modo <completo\|compativel>`. Valida tudo e grava `/etc/sddm.conf.d/zz-xinguos-session.conf`, `/etc/xinguos/sessao.conf` e `/etc/xinguos/gaming.conf` |
| `/usr/share/polkit-1/actions/org.xinguos.sessao.policy` + `/usr/share/polkit-1/rules.d/49-xinguos-sessao.rules` | libera o helper |
| `/usr/share/wayland-sessions/xinguos-gaming.desktop` | "XInguOS Gaming" → `/usr/lib/xinguos/xinguos-gaming-sessao` |
| `/usr/lib/xinguos/xinguos-gaming-sessao` | lê `MODO_GAMING` e roda `gamescope-session-plus steam` (completo) ou `kwin_wayland --xwayland --exit-with-session "steam -gamepadui -steamos3"` (compatível); mede a duração e cuida do contador em `~/.local/state/xinguos/gaming-falhas` |
| `/usr/lib/systemd/system/xinguos-sessao-boot.service` + script | antes do SDDM: aplica `PADRAO` (gaming/desktop) ao `Session=` do autologin |
| `/usr/share/applications/org.xinguos.gaming.desktop` | "Voltar ao Gaming Mode", `X-KDE-Shortcuts=Meta+Shift+G` |
| `/etc/xdg/autostart/xinguos-gaming-aviso.desktop` + script | no Desktop: se o Gaming caiu 2 vezes, notifica e sugere o modo compatível |
| `/etc/xdg/MangoHud/MangoHud.conf` | preset leve, escondido, liga com Shift+F12 |

**Fluxo:**
- `xinguos-session-select gaming`:
  1. `pkexec helper sessao $USER xinguos-gaming.desktop`;
  2. `loginctl terminate-session $XDG_SESSION_ID`;
  3. o SDDM (`Relogin=true`) entra no Gaming.
- `desktop`/`plasma` faz o mesmo com `plasma.desktop`.
- `--default` e `--modo` só gravam.

---

### Task 1: troca de sessão (`xinguos-session-select` + helper + polkit + boot)

**Testes (`tests/gaming.bats`, com stubs `pkexec` que executa direto, `loginctl` que registra e `id`):**
- `gaming`: grava o autologin do usuário com `Session=xinguos-gaming.desktop` e `Relogin=true`, depois encerra a sessão;
- `plasma` (o que o Steam chama) e `desktop`: `Session=plasma.desktop`;
- argumento inválido → 2, nada gravado;
- helper:
  - recusa sessão inexistente;
  - recusa usuário diferente do `PKEXEC_UID`;
  - recusa nome com `/` ou `..`;
  - `padrao gaming` → `PADRAO=gaming`; `modo completo` → `MODO_GAMING=completo`, sem a marca de gerado (vira escolha do usuário);
- boot: `PADRAO=desktop` com o autologin em gaming troca para `plasma.desktop`; `ultima` não mexe; sem o arquivo de autologin, não faz nada;
- a regra do polkit cita o action id, o `wheel`, `subject.active` e `subject.local`, e a policy aponta o `exec.path` para o helper;
- `os-session-select` repassa os argumentos.

- [ ] RED → GREEN → commit `feat(gaming): troca de sessão Gaming ↔ Desktop sem senha`.

### Task 2: sessão Gaming + contador de falhas + aviso

**Testes:**
- modo `completo` roda `gamescope-session-plus steam` e `compativel` roda o `kwin_wayland … steam -gamepadui -steamos3`. Os stubs registram, e o modo vem de `gaming.conf`, com `compativel` se não existir;
- falha rápida (stub sai com 1, relógio falso com `XINGUOS_AGORA`) → contador 1; segunda → 2, chama `xinguos-session-select desktop` e grava `aviso`;
- sessão longa zera o contador;
- saída 0 rápida (o usuário saiu pelo menu) não conta;
- o aviso do desktop chama `notify-send` uma vez e apaga a marca.

- [ ] RED → GREEN → commit `feat(gaming): sessão XInguOS Gaming com contador de falhas`.

### Task 3: pacote `xinguos-gaming`, metapacote `xinguos`, jogo com peso 1000 no foco

- **`xinguos-gaming`:**
  - `depends=(steam gamescope gamescope-session-git gamescope-session-steam-git mangohud lib32-mangohud gamemode lib32-gamemode kwin polkit xinguos-hwdetect libnotify)`;
  - `optdepends=heroic-games-launcher-bin`, vendorizado do AUR em `ordem.txt`.
  - O ProtonUp-Qt vem pelo Flathub, no app de boas-vindas (o pacote do AUR puxa 6 dependências do AUR).
- **`xinguos`** (metapacote): `xinguos-base xinguos-kernels xinguos-desktop xinguos-gaming xinguos-boasvindas xinguos-branding`.
- **`xinguos-foco` 0.1.0-4:** `peso()` dá 1000 a apps `steam_app_*` em foco (spec 7.2). Teste pytest.
- **Smoke:** `pacman -Sp xinguos` resolve, e `xinguos-gaming` instala e traz `/usr/lib/os-session-select`.

- [ ] RED → GREEN → commit `feat(gaming): pacote xinguos-gaming e metapacote xinguos`.

### Task 4: boas-vindas ganha Sessão padrão, Gaming Mode e ProtonUp-Qt

- O catálogo ganha `protonup-qt` (Flathub `net.davidotek.pupgui2`, marcado).
- A janela ganha dois `ComboBox`:
  - "Ao ligar, abrir": Última usada / Desktop / Gaming;
  - "Gaming Mode": Compatível / Completo.
  - Os dois chamam `xinguos-session-select --default/--modo`, e o estado atual vem de `--status`.
- `xinguos-boasvindas` 0.1.0-2 depende de `xinguos-gaming`? **Não**: o app só mostra os controles se `xinguos-session-select` existir.
- Testes: catálogo; backend `sessao()`/`definirSessao()` com o `subprocess` falso; QML carrega.

- [ ] RED → GREEN → commit `feat(boasvindas): sessão padrão, modo do Gaming e ProtonUp-Qt`.

### Task 5: ISO de instalação com o Gaming Mode

- O `iso/instalar/pacotes.txt` troca `steam gamescope gamescope-session-* mangohud` pelo `xinguos-gaming`.
- O `teste-instalacao.sh` confere `xinguos-gaming` instalado e a sessão `xinguos-gaming.desktop`.
- Dispatch com `iso_instalar=true` → `D:\isos\Linux\xinguos.iso` com `sha256sum -c`.

- [ ] commit `feat(iso): Gaming Mode na ISO de instalação`.

### Task 6: [MANUAL — Xingu] Marco 0 teste 2 + checklist 10.3 do Gaming

| Faça | Esperado |
|---|---|
| No Desktop, Win+Shift+G | a sessão fecha e o Steam abre em tela cheia (modo compatível) |
| No Steam: Ligar → Mudar para a Área de Trabalho | volta ao Plasma sem pedir senha |
| Repetir 3 vezes | sempre troca |
| Boas-vindas → Gaming Mode: Completo, depois Win+Shift+G | gamescope + Steam. **Se a tela ficar preta:** Ctrl+Alt+F3, login, `xinguos-session-select --modo compativel` e reiniciar. Depois de 2 quedas ele volta sozinho para o Desktop |
