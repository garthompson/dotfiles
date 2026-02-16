# Machine-Specific Configuration

Base configs are shared. Machine-specific overrides live in `machines/HOSTNAME/`.

## Directory Structure

```
machines/
  work-macbook/
    .gitconfig.local      # Git identity (work email)
    .zshrc.local          # Zsh overrides (work paths, aliases)
    .env.zsh              # Secret env vars (git-ignored)
    README.md             # Notes about this machine
  personal-macbook/
    .gitconfig.local
    .zshrc.local
    .env.zsh
    README.md
```

## Creating a New Machine Profile

```bash
MACHINE=$(hostname -s)
mkdir -p ~/dotfiles/machines/$MACHINE
```

### .gitconfig.local

Included via `[include]` in the base `.gitconfig`:

```ini
[user]
    email = work@company.com
```

### .zshrc.local

Sourced at the end of `.zshrc`:

```bash
export PATH="/opt/work-tools/bin:$PATH"
alias proj="cd ~/work/projects"
```

### .env.zsh

Git-ignored. For secrets only:

```bash
export GITHUB_TOKEN="ghp_..."
```

## Linking Machine Configs

```bash
MACHINE=$(hostname -s)
ln -sf ~/dotfiles/machines/$MACHINE/.gitconfig.local ~/.gitconfig.local
mkdir -p ~/.config/zsh
ln -sf ~/dotfiles/machines/$MACHINE/.zshrc.local ~/.config/zsh/local.zsh
```

The install script does this automatically.

## How Base + Override Works

Base `.gitconfig` includes the local override:
```ini
[include]
    path = ~/.gitconfig.local
```

Base `.zshrc` sources local configs:
```bash
[[ -f ~/.config/zsh/local.zsh ]] && source ~/.config/zsh/local.zsh
```

If no override file exists, the base config works on its own.
