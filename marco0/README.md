# Marco 0: a GTX 1060 aguenta o XInguOS?

Antes de construir o resto, a gente testa no seu PC real as partes arriscadas: driver, Gaming Mode, troca de sessão e VR. O resultado decide se a 1060 usa o **Gaming Mode completo** ou o **compatível** (spec, seção 4.4).

Tudo roda pela **ISO de teste ao vivo** pelo Ventoy, **sem formatar nada**. A instalação no SSD fica pro Plano 2.

Anote os resultados em [`resultados.md`](resultados.md). O plano completo está em `docs/superpowers/plans/2026-11-08-xinguos-plano1-infra-marco0.md` (adendo, Tasks 14 e 10).

## Parte 1: primeiro boot e persistência

A ISO fica em `D:\isos\Linux\xinguos-teste.iso`. Ela é gerada pelo CI (`gh workflow run repo.yml -f iso=true`) e baixada com `gh run download`. O nome é sempre o mesmo, então a persistência continua valendo a cada ISO nova.

1. No PC, abra o menu do Ventoy e escolha **`xinguos-teste.iso`**. Na primeira vez **não** existe persistência ainda. O sistema entra sozinho no Plasma como `xingu`, sem senha.
2. No Konsole, rode:
   ```bash
   sudo criar-persistencia
   ```
   Ele cria um arquivo de 80 GB em `D:\persistence\` e liga esse arquivo à ISO no `ventoy.json`. Antes, faz backup do `ventoy.json` em `ventoy.json.antes-xinguos`. No HD USB isso leva uns 15 a 25 minutos.
   - **Se der "não consegui montar"**: volte pro Windows, acrescente `{ "VTOY_LINUX_REMOUNT": "1" }` dentro da lista `"control"` de `D:\ventoy\ventoy.json`, boote de novo e rode o comando outra vez. Isso também pode ser pedido pro Claude.
3. Reinicie e escolha a ISO de novo. Agora o Ventoy pergunta qual persistência usar: escolha **`xinguos-teste.dat`**.
4. **Pra conferir:**
   - crie um arquivo qualquer em `~`, reinicie e veja se ele continua lá;
   - `nvidia-smi` mostra `GeForce GTX 1060 6GB` e o driver `580.`;
   - `cat /sys/module/nvidia_drm/parameters/modeset` mostra `Y`;
   - `echo $XDG_SESSION_TYPE` mostra `wayland`.
5. Rode `gh auth login` e depois `gh repo clone Guilherme-XHP/xinguos`.

## Parte 2: os testes

Steam, gamescope, MangoHud, gamescope-session e o protótipo de troca de sessão **já vêm na ISO**.

| # | Teste | Passa se… |
|---|---|---|
| 1 | Use o Plasma por 15 minutos (Firefox, Dolphin, um vídeo) | não congela nem pisca, e `journalctl -b -p err \| grep -i nvidia` vem vazio ou só com avisos inofensivos |
| 2 | Saia do Plasma, vá pra TTY3 (Ctrl+Alt+F3), entre como `xingu` e rode `gamescope -e -- steam -gamepadui` | a interface do Deck abre, um jogo inicia e **a tela não fica preta** com o cursor parado ou escondido por 2 minutos |
| 3 | Rode `steamos-session-select gamescope`. Na sessão Steam, use "Mudar para a Área de Trabalho". No Plasma, rode `steamos-session-select gamescope` de novo | o ciclo funciona **3 vezes**, sem travar e voltando sempre pra sessão certa |
| 4 | Instale o SteamVR pelo Steam. No Quest 2, abra o Steam Link, conecte e jogue Half-Life: Alyx por 10 minutos | funciona; anote FPS, travadas e áudio. O carregamento fica mais lento por causa do HD USB, e isso é esperado |
| 5 | Adicione o widget "Menu global" no painel de cima. Rode `sudo pacman -Syu kdenlive gimp`. Abra o Kdenlive, o Dolphin e o GIMP | anote em quais o menu foi pro topo |
| 6 | Deixe o PC 5 minutos parado com `top` aberto | nenhum processo fica subindo a CPU acima de 10% de forma recorrente; anote os culpados |

**Se no teste 3 a sessão voltar pra mesma de antes** (o SDDM não releu o arquivo), anote isso e tente `sudo systemctl restart sddm` no lugar. Esse é o plano B.

**Na ISO de teste, o `sudo` não pede senha pra nada.** Por isso o teste 3 não valida a regra estreita do sudoers do protótipo. Isso fica pro Plano 3.

**Decisão:**
- o modo da 1060 fica **completo** se os testes 2 e 3 passarem;
- fica **compatível** se o 2 falhar (tela preta).

No fim, faça o commit do `resultados.md`.

## Sobre o protótipo

Tudo em `prototipo/` é **descartável**. Na ISO, ele fica no gancho oficial do gamescope-session (`/usr/lib/os-session-select`) e também em `/usr/local/bin/steamos-session-select`. A versão de verdade (helper com polkit, contador de falhas e modo compatível) vem no Plano 3 (`xinguos-gaming`). O `prototipo/instalar.sh` só serve pra um Arch instalado, fora da ISO.
