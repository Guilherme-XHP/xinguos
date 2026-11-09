# Pendências adiadas

Itens pequenos que as revisões acharam e que ficaram para depois. Quem pegar um, risca aqui.

## Plano 4 (desktop e apps)

- O dock aponta para `firefox.desktop`/`steam.desktop` mesmo sem o xinguos-apps ou o Plano 3. Usar `preferred://browser` e conferir se o app existe.
- O notificador do Discover continua no autostart, e a spec 5.4 pede que ele não fique rodando.
- Faltam testes do `xinguos-primeiro-login` para HOME sem permissão de escrita e para `.antes-xinguos` já existente.
- O build do CI instala os GB do xinguos-apps (`makepkg -si`) a cada push no main.
- Uma marca `desktop-v2` futura não pode regravar tudo: a v2 só grava as chaves novas.
- A concurrency por job cancela um job pendente quando outro entra na fila. Basta rodar de novo.
- Decisões em aberto para o Xingu revisar:
  - a barra de cima não mostra o nome do app em foco;
  - o ícone do launcher é provisório até o Plano 6;
  - o PhotoGIMP é só optdepends;
  - o Krohnkite tem PKGBUILD próprio, então atualizar vira tarefa manual.
- ~~Vão para o Plano 5: o estado do Win+T não sobrevive ao reiniciar, e o autotile é por app.~~ O autotile por app foi feito no Plano 5, e o Win+T segue sem persistir (decisão no spec 7.2.1).

## Plano 5 (foco)

- `IOWeight` só tem efeito em HD (BFQ). Em SSD/NVMe, com o scheduler `none`, a prioridade de disco não vale: documentar ou usar iocost.
- Antes de o daemon subir, o foco se perde. A correção é a ativação por D-Bus (`org.xinguos.Foco.service` com `SystemdService=`).
- `units` cresce sem limite, e o `recarregar` chama o systemctl em scopes que já morreram. O subprocess é síncrono dentro do loop asyncio.
- ~~Com o nome já em uso, o daemon sai com 1 e reinicia a cada 5 s.~~ Agora sai com 3 e o serviço tem `RestartPreventExitStatus=3`.
- Painel:
  - mostra "Salvo." mesmo quando o kwriteconfig6 falha;
  - sobrescreve o TOML do usuário quando ele é inválido;
  - sobrescreve o `ignoreClass` que tenha sido editado à mão no Krohnkite.
- `test_qml_carrega` não instancia os delegates, porque o banco do teste está vazio.
- `/etc/xdg/kwinrc` no xinguos-foco é redundante com o `EnabledByDefault` e vai dar conflito quando o desktop precisar desse arquivo.
- O spec 7.2 pede peso 1000 para jogo `steam_app_*` em foco. Hoje ele recebe 500.
- O banco faz um commit com fsync a cada 30 s em journal rollback. Melhor usar WAL + `synchronous=NORMAL`.
- Para o Xingu revisar:
  - os avisos de limite não têm botões (por exemplo, "mais 15 min");
  - a ociosidade vem do swayidle;
  - o nome curto vai junto no `ignoreClass`;
  - o painel não usa Kirigami.

## Plano 6 (branding, boas-vindas, ISO de instalação)

- ~~`grubcfg.conf`: `keepDistributor` → `keep_distributor`; `GRUB_DEFAULT=saved` sem `GRUB_SAVEDEFAULT`.~~ Corrigido. Os `defaults` nunca valiam (o grub do Arch já traz `/etc/default/grub`; faltava `always_use_defaults: true`), então o os-prober ficava desligado. Agora: `GRUB_DEFAULT=0` (Btrfs não grava o grubenv), os-prober ligado, gfxterm e tema.
- A VTOYEFI pode ser oferecida como ESP nos modos "ao lado" e "substituir". A instalação falha no bootloader, mas o disco fica salvo pelo somente leitura.
- O os-prober pode criar uma entrada falsa no GRUB para a ISO do Ventoy.
- O `userdel live` nunca roda numa instalação real, porque o usuário é criado no boot. É inofensivo.
- `build-repo`: um pacote compilado com o PKGBUILD mudado sem subir o pkgrel é republicado em silêncio. Comparar `pkgver`/`depends` do `.SRCINFO`.
- Boas-vindas:
  - o script vai para `/tmp/xinguos-boasvindas.sh` (nome previsível) quando não há `XDG_RUNTIME_DIR`;
  - o Android SDK depende do JDK do xinguos-apps.
- ~~Plymouth e tema do GRUB ficam para o branding final.~~ Feitos no xinguos-branding (logo XHP no vinho). Falta ver no PC: o plymouth com o driver 580xx (o splash usa o simpledrm até o nvidia carregar) e o GRUB em 1920x1080.
- O teste de instalação no CI cobre o pós-instalação no chroot. O Calamares gráfico (particionar, GRUB de verdade, primeiro boot) só foi testado à mão.

## Plano 3 (Gaming Mode)

- `xinguos-sessao-root`:
  - ~~se falhar no meio, deixa `zz-xinguos-session.conf.XXXXXX` (falta `trap`);~~ corrigido;
  - sem `PKEXEC_UID`, pula a checagem de usuário (só o root chega lá).
- A sessão "Steam Big Picture" do upstream aparece no SDDM e pula o contador e a troca.
- O cursor `steam` do upstream pode vazar para apps GTK no Plasma.
- Foco: deixa peso 100 no scope do Steam quando o jogo perde o foco, por cima do "sempre" do steam.
- ~~O ícone "Voltar ao Gaming Mode" só aparece no launcher, não na área de trabalho (spec 4.2).~~ Vai também em `/etc/skel/Desktop`.
- Boas-vindas: se o pkexec falhar, o ComboBox continua mostrando o valor novo.
- O Plasma pode cancelar o logout (app com trabalho não salvo). Nesse caso a troca fica gravada para o próximo logout.
- Modo compatível: um launcher de fora do Steam pode ser organizado pelo Krohnkite (o Steam e os jogos estão no `ignoreClass`).
- Marco 0 teste 2 (gamescope na GTX 1060) ainda não foi feito. A 1060 começa no modo compatível.

## Teste no PC real (2026-11-09) e tema XHP

- Gaming Mode no live: "abria, não fazia nada e voltava pro desktop". O `gaming-falhas` não existia, então a sessão Gaming nem chegou a terminar pelo script. Causa não achada. A sessão agora grava `~/.local/state/xinguos/gaming-sessao.log`, e o `xinguos-teste` junta esse log com o do SDDM e o do Steam.
  - Pista: o kwin_wayland do Gaming é filho direto do script, então os erros dele iam só para o `wayland-session.log` do SDDM, nunca para o journal (o do Plasma vai, por ser serviço do systemd). Agora vão para `gaming-ultima-sessao.log`. A troca grava qual `Session=` o SDDM vai ler, e um sinal que mate a sessão fica no log.
  - `xinguos-teste --gaming` abre o modo compatível numa janela dentro do Plasma, sem SDDM. Separa "o Steam não sobe" de "a troca de sessão não pega".
- Estudar o `gamescope-session-cachyos` (CachyOS) para o modo completo, para quando houver GPU Turing+/AMD. O Bazzite não dá Gaming Mode para GTX 10xx.
- Materia-Color e Materia-Dark são de 2022 (Plasma 5). Conferir no PC se o painel e a decoração ficam certos no Plasma 6.
