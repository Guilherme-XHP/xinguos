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
- Vão para o Plano 5: o estado do Win+T não sobrevive ao reiniciar, e o autotile é por app.
