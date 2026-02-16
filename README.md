# Dotfiles

macOS configuration files managed with [GNU Stow](https://www.gnu.org/software/stow/).

## Quick Start

```bash
git clone https://github.com/YOUR_USERNAME/dotfiles.git ~/dotfiles
cd ~/dotfiles
cp templates/variables.env.example variables.env
# Edit variables.env with your values
./scripts/install.sh
```

See [INSTALLATION.md](INSTALLATION.md) for the full setup guide.

## Structure

| Directory    | Description                                  | Stowed? |
|-------------|----------------------------------------------|---------|
| `scripts/`  | Core utilities (backup, stow, brew, install) | No      |
| `zsh/`      | Zsh shell config (zsh4humans, p10k)          | Yes     |
| `git/`      | Git configuration                            | Yes     |
| `ssh/`      | SSH client config                            | Yes     |
| `nvim/`     | Neovim configuration                         | Yes     |
| `gh/`       | GitHub CLI configuration                     | Yes     |
| `vscode/`   | VS Code settings, keybindings, extensions    | Yes     |
| `python/`   | uv and pip configuration                     | Yes     |
| `iterm2/`   | iTerm2 preferences                           | Yes     |
| `jetbrains/`| JetBrains IDE settings                       | Yes     |
| `homebrew/` | Brewfiles for package management             | No      |
| `macos/`    | macOS system preferences scripts             | No      |
| `machines/` | Machine-specific overrides                   | No      |
| `docs/`     | Documentation                                | No      |

## Key Concepts

### Stow Packages

Each tool's config is a separate "package" directory that mirrors `$HOME`. Running `stow git` creates symlinks from `git/.gitconfig` to `~/.gitconfig`. The `stow-link.sh` wrapper adds safety checks, conflict detection, and automatic backups.

### Templates

Files ending in `.template` contain `{{PLACEHOLDER}}` variables for secrets and machine-specific values. These are rendered during setup using values from `variables.env` (git-ignored).

### Machine-Specific Configs

Base configs are shared across machines. Machine-specific overrides live in `machines/HOSTNAME/` and are included/sourced by the base configs. Private secrets (`.env.zsh`) are git-ignored.

### Backups

Before any change, `backup.sh` creates timestamped backups in `backups/` (git-ignored) with a manifest of what was saved. Rollback is always possible.

## Documentation

- [INSTALLATION.md](INSTALLATION.md) - Complete setup guide with rollback procedures
- [docs/STOW.md](docs/STOW.md) - GNU Stow usage
- [docs/MACHINE-SETUP.md](docs/MACHINE-SETUP.md) - Machine-specific configuration
- [docs/SECRETS.md](docs/SECRETS.md) - Template variables and secrets
- [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) - Common issues

## Scripts

| Script            | Purpose                                          |
|-------------------|--------------------------------------------------|
| `backup.sh`       | Timestamped backups before any changes           |
| `stow-link.sh`    | GNU Stow wrapper with conflict detection         |
| `brew-sync.sh`    | Homebrew dump/diff/install                       |
| `install.sh`      | Interactive installation orchestrator            |
