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

## Desenvolver o XInguOS de dentro do XInguOS

```bash
sudo pacman -S --needed git github-cli base-devel bats shellcheck namcap python-pytest python-yaml
git clone https://github.com/Guilherme-XHP/xinguos.git && cd xinguos
gh auth login
bats tests/                 # os testes rodam direto (aqui é Linux de verdade)
```

O ciclo de uma versão nova:

1. mudar o pacote e subir o `pkgrel` (pacote publicado nunca muda com o mesmo nome);
2. `git push` na `main`: o CI compila, assina e publica no `[xinguos]`;
3. `sudo pacman -Syu` no próprio PC já pega a versão nova;
4. ISO nova, quando precisar: `tools/gerar-iso.sh [branch] [pasta]` (o CI gera, o script baixa e confere).
