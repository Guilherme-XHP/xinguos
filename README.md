# XInguOS

Distro pessoal do Xingu, baseada em **Arch Linux puro**: gaming com Gaming Mode no estilo Steam Deck, KDE Plasma com atalhos do Windows e barra de topo no estilo Mac, e compatível com hardware antigo e novo (incluindo GTX 10xx/Pascal).

- Design: [docs/superpowers/specs/2026-11-08-xinguos-design.md](docs/superpowers/specs/2026-11-08-xinguos-design.md)

## Usar o repositório `[xinguos]` num Arch puro

Fingerprint da chave de assinatura: `71A4F9C98EC5F556F6A0A16784B5DF2CB84BFCD0`

```bash
# 1. confiar na chave do XInguOS (compare o fingerprint acima)
curl -L -o /tmp/xinguos.gpg https://github.com/Guilherme-XHP/xinguos/releases/download/repo-x86_64/xinguos.gpg
sudo pacman-key --add /tmp/xinguos.gpg
sudo pacman-key --lsign-key 71A4F9C98EC5F556F6A0A16784B5DF2CB84BFCD0
```

```ini
# 2. adicionar ao final do /etc/pacman.conf
[xinguos]
SigLevel = Required DatabaseOptional
Server = https://github.com/Guilherme-XHP/xinguos/releases/download/repo-x86_64
```

```bash
# 3. instalar o keyring (atualizações da chave chegam por ele)
sudo pacman -Syu xinguos-keyring
```

Depois disso, instale o que quiser. Por exemplo, o driver da GTX 10xx:

```bash
sudo pacman -S nvidia-580xx-dkms nvidia-580xx-utils lib32-nvidia-580xx-utils
```
