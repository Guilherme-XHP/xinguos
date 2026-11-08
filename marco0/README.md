# Marco 0: a GTX 1060 aguenta o XInguOS?

Antes de construir o resto, a gente testa no seu PC real as partes arriscadas: driver, Gaming Mode, troca de sessão e VR. O resultado decide se a 1060 usa o **Gaming Mode completo** ou o **compatível** (spec, seção 4.4).

Anote tudo em [`resultados.md`](resultados.md). O plano completo está em `docs/superpowers/plans/2026-11-08-xinguos-plano1-infra-marco0.md` (Tasks 9 e 10).

## Parte 1: backup e instalação

> ⚠️ O HD USB de 500 GB (ST500LM0) é o **Ventoy com todos os backups**. **Nunca** escolha ele no instalador. Formate só o **SanDisk SSD PLUS 1000GB**.

1. **Backup** em `D:\Guilherme`: `C:\XIngu` inteiro, Documentos, Imagens, Vídeos e saves sem Steam Cloud. Abra 3 arquivos da cópia pra conferir.
2. Boote o `D:\isos\Linux\archlinux-x86_64.iso` pelo Ventoy.
   - Se o `archinstall` reclamar de chave ou assinatura, rode `pacman -Sy archlinux-keyring` antes.
3. Rode `archinstall` com estas opções:
   - **Idioma:** pt_BR.UTF-8. **Teclado:** `br-abnt2`. **Fuso:** America/Sao_Paulo.
   - **Disco:** SanDisk → apagar tudo → **btrfs** (subvolumes padrão, compressão ligada).
   - **Snapshots:** snapper. **Bootloader:** GRUB.
   - **Kernels:** `linux-zen` e `linux-lts`.
   - **Perfil:** Desktop → KDE Plasma, com SDDM.
   - **Driver gráfico: "All open-source".** ⚠️ **Não** escolha "Nvidia (proprietary)": ele instala o driver que não funciona na 1060.
   - **Áudio:** PipeWire.
   - **Repositórios extras:** **multilib**.
   - **Pacotes extras:** `linux-zen-headers linux-lts-headers git firefox github-cli`.
4. Já no Plasma, **instale o driver pelo `[xinguos]`** seguindo o README da raiz do repositório (adicionar a chave, colocar o bloco no `pacman.conf` e instalar o `xinguos-keyring`). Depois:
   ```bash
   sudo pacman -Sy nvidia-580xx-dkms nvidia-580xx-utils lib32-nvidia-580xx-utils
   ```
   Em `/etc/default/grub`, acrescente `nvidia-drm.modeset=1` dentro de `GRUB_CMDLINE_LINUX_DEFAULT`. Depois rode:
   ```bash
   sudo grub-mkconfig -o /boot/grub/grub.cfg
   ```
   e reinicie.
5. **Pra conferir:**
   - `nvidia-smi` mostra `GeForce GTX 1060 6GB` e o driver `580.`;
   - `cat /sys/module/nvidia_drm/parameters/modeset` mostra `Y`;
   - `echo $XDG_SESSION_TYPE` mostra `wayland`.
6. Instale o Claude Code (instalador oficial), rode `gh auth login` e depois `gh repo clone Guilherme-XHP/xinguos`. As próximas sessões continuam daí.

## Parte 2: os testes

| # | Teste | Passa se… |
|---|---|---|
| 1 | Use o Plasma por 15 minutos (Firefox, Dolphin, um vídeo) | não congela nem pisca, e `journalctl -b -p err \| grep -i nvidia` vem vazio ou só com avisos inofensivos |
| 2 | `sudo pacman -S steam gamescope mangohud lib32-mangohud`. Saia do Plasma, vá pra TTY3 (Ctrl+Alt+F3), faça login e rode `gamescope -e -- steam -gamepadui` | a interface do Deck abre, um jogo inicia e **a tela não fica preta** com o cursor parado ou escondido por 2 minutos |
| 3 | Instale `gamescope-session-git` e depois `gamescope-session-steam-git` pelo AUR (`git clone https://aur.archlinux.org/<nome>.git`, `cd <nome>`, `makepkg -si`). Confira se existe `/usr/share/wayland-sessions/gamescope-session-steam.desktop`. Rode `cd marco0/prototipo && sudo ./instalar.sh`. Entre na sessão Steam pelo SDDM → "Mudar para a Área de Trabalho" → no Plasma, `steamos-session-select gamescope` | o ciclo funciona **3 vezes** sem pedir senha e sem travar |
| 4 | Instale o SteamVR pelo Steam. No Quest 2, abra o Steam Link, conecte e jogue Half-Life: Alyx por 10 minutos | funciona; anote FPS, travadas e áudio |
| 5 | Adicione o widget "Menu global" no painel de cima. Rode `sudo pacman -S kdenlive gimp`. Abra o Kdenlive, o Dolphin e o GIMP | anote em quais o menu foi pro topo |
| 6 | Deixe o PC 5 minutos parado com `top` aberto | nenhum processo fica subindo a CPU acima de 10% de forma recorrente; anote os culpados |

**Se no teste 3 a sessão voltar pra mesma de antes** (o SDDM não releu o arquivo), anote isso e tente, no lugar do `loginctl`, rodar `sudo systemctl restart sddm`. Esse é o plano B.

**Decisão:**
- o modo da 1060 fica **completo** se os testes 2 e 3 passarem;
- fica **compatível** se o 2 falhar (tela preta).

No fim, faça o commit do `resultados.md`.

## Sobre o protótipo

Tudo em `prototipo/` é **descartável**. Ele usa `sudo` sem senha para um único helper, só pra testar a ideia. A versão de verdade (helper com polkit, contador de falhas e modo compatível) vem no Plano 3 (`xinguos-gaming`).
