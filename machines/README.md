# Machine-Specific Configs

Per-machine configuration overrides. Each subdirectory is named after a hostname.

## Creating a Profile

```bash
mkdir -p machines/$(hostname -s)
```

## Files

| File               | Purpose                        | Git-tracked? |
|--------------------|--------------------------------|--------------|
| `.gitconfig.local` | Git identity and settings      | Yes          |
| `.zshrc.local`     | Zsh paths, aliases, tools      | Yes          |
| `.env.zsh`         | Secret environment variables   | No           |
| `README.md`        | Notes about this machine       | Yes          |

## Linking

```bash
MACHINE=$(hostname -s)
ln -sf ~/dotfiles/machines/$MACHINE/.gitconfig.local ~/.gitconfig.local
mkdir -p ~/.config/zsh
ln -sf ~/dotfiles/machines/$MACHINE/.zshrc.local ~/.config/zsh/local.zsh
```

The base `.gitconfig` and `.zshrc` include these files automatically if they exist.

See [docs/MACHINE-SETUP.md](../docs/MACHINE-SETUP.md) for the full guide.
