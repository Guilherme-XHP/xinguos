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

**Modo padrão da GTX 1060:** completo | compatível
