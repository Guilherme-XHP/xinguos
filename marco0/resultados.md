# Marco 0: resultados na GTX 1060

- **Data:** 2026-11-08 (primeiro boot ao vivo, sem persistência)
- **Kernel:** 7.2.14-arch1-1 (o da ISO de teste)
- **Driver:** 580.196.07 (CUDA 13.0)
- **Versão do gamescope:** (anotar no teste 2)

| # | Teste | Resultado (ok / ok com ajuste / falhou) | Notas | Plano B usado |
|---|---|---|---|---|
| 0 | Boot da ISO pelo Ventoy | ok com ajuste | Na 1ª tentativa o GRUB deu `verification requested but nobody cares: /arch/boot/x86_64/vmlinuz-...` e `you need to load the kernel first`; depois bootou. `nvidia-smi`: GTX 1060 6GB, 170 MiB em uso; modeset `Y`; sessão `wayland`; Plasma entrou sozinho como `xingu`; Steam abriu | O modo normal do Ventoy falha; bootou escolhendo **outro modo do Ventoy** (anotar o nome exato). ⚠️ Conferir se a persistência funciona nesse modo |
| 1 | Plasma Wayland estável com o 580xx | parcial | Subiu limpo, sem tela preta. Faltam os 15 minutos de uso | |
| 2 | `gamescope -e -- steam -gamepadui` (tela preta?) | | | |
| 3 | Troca de sessão Gaming ↔ Desktop (3 ciclos) | | | |
| 4 | Steam Link VR + SteamVR + Half-Life: Alyx (10 min) | | | |
| 5 | Menu global (Kdenlive / Dolphin / GIMP) | | | |
| 6 | Desktop parado: picos de CPU | | | |

**Persistência (Task 14): ADIADA (decisão do Xingu, 2026-11-08).** O `criar-persistencia` falhou antes de criar qualquer coisa: o `D:` ficou intacto. Provável causa: a partição do Ventoy não monta no live, e/ou o modo alternativo de boot. Além disso, o modo normal do Ventoy dá erro no GRUB com a ISO. O live serve só para testes rápidos (o cow tem 8 GB em RAM); o teste 4 (Alyx, 67 GB) fica para quando houver persistência ou o sistema estiver instalado.

**Modo padrão da GTX 1060:** completo | compatível

## Plano 2 no live (2026-11-09)

| Teste | Resultado | Notas |
|---|---|---|
| `zramctl` | ok | `/dev/zram0` zstd 5.8G em uso como [SWAP] |
| `sysctl vm.swappiness` | ok | 180 |
| `xinguos-hwdetect --detectar` | ok | `perfil=nvidia-580xx`, sem aviso: a iGPU Intel está desligada na BIOS, só a 1060 aparece |
| `sudo pacman -S nvidia-open-dkms` (guard) | não testado | O live não tinha espelhos: o `mirrorlist` do perfil baseline vem todo comentado e o `pacman -Sy` falhava com "no servers configured". Corrigido na ISO seguinte (mirrorlist com geo.mirror.pkgbuild.com + C3SL/UFPR). Retestar com `sudo pacman -Sy` e depois `sudo pacman -S nvidia-open-dkms` |

Observação: no boot aparecem várias linhas `Invalid ELF header magic: != ELF` durante o hook do archiso; o boot segue normal.
