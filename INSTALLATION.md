# Installation Guide

Complete guide for setting up dotfiles on a new or existing Mac.

## Prerequisites

You need **Homebrew** installed. Everything else can be installed through it.

```bash
# Install Homebrew (also installs Xcode Command Line Tools)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install GNU Stow (required for symlinking configs)
brew install stow
```

## Quick Start

```bash
# 1. Clone the repository
git clone https://github.com/YOUR_USERNAME/dotfiles.git ~/dotfiles
cd ~/dotfiles

# 2. Create your variables file from the template
cp templates/variables.env.example variables.env
# Edit variables.env with your actual values (name, email, key paths, etc.)

# 3. Run the interactive installer
./scripts/install.sh
```

The installer will walk you through each component interactively.

## Manual Setup (Component by Component)

If you prefer manual control over each step, follow this order (lowest risk first).

### 1. Back Up Existing Configs

Always back up before making changes:

```bash
./scripts/backup.sh pre-setup ~/.zshrc ~/.zshenv ~/.p10k.zsh ~/.gitconfig ~/.ssh/config ~/.config
```

This creates a timestamped backup in `backups/` with a manifest of everything saved.

### 2. Set Up Template Variables

```bash
cp templates/variables.env.example variables.env
```

Edit `variables.env` with your values:

```bash
GIT_NAME="Your Name"
GIT_EMAIL="you@example.com"
KEELVAR_KEY_PATH="~/.ssh/id_rsa_work"
PERSONAL_KEY_PATH="~/.ssh/id_rsa_personal"
PYTHON_VENV_PATH="~/venvs/.nvim-venv"
```

### 3. Git Configuration (Low Risk)

```bash
# Check what would be linked
./scripts/stow-link.sh git check

# Simulate (dry run)
./scripts/stow-link.sh git simulate

# Link (backs up conflicts automatically)
./scripts/stow-link.sh git link

# Verify
git config user.name
git config user.email
```

### 4. GitHub CLI

```bash
./scripts/stow-link.sh gh link
gh auth status
```

### 5. Neovim

```bash
./scripts/stow-link.sh nvim link
# Open nvim and verify plugins/config load
```

### 6. SSH Configuration

```bash
./scripts/stow-link.sh ssh link

# Fix permissions (critical for SSH)
chmod 700 ~/.ssh
chmod 600 ~/.ssh/config

# Test a connection
ssh -T git@github.com
```

### 7. Python (uv/pip config)

```bash
./scripts/stow-link.sh python link
```

### 8. VS Code

```bash
./scripts/stow-link.sh vscode link
# Restart VS Code to pick up settings
```

### 9. Zsh Configuration (Highest Risk - Do Last)

This replaces your shell configuration. Be careful.

```bash
# Full backup first
./scripts/backup.sh pre-zsh ~/.zshrc ~/.zshenv ~/.p10k.zsh ~/.config/zsh

# Check for conflicts
./scripts/stow-link.sh zsh check

# Link
./scripts/stow-link.sh zsh link

# IMPORTANT: Open a NEW terminal window to test
# Do NOT close your current terminal until you verify the new one works
```

**Verification checklist** (in the new terminal):
- Terminal opens without errors
- Prompt displays correctly (Powerlevel10k)
- Aliases work: run `alias` to list them
- Tab completion works: type `git ` then press Tab
- fzf works: press Ctrl+R for history search
- PATH is correct: `echo $PATH`
- zsh4humans works: `z4h update`

### 10. Homebrew Packages

```bash
# See what would change
./scripts/brew-sync.sh diff

# Install packages from Brewfile
./scripts/brew-sync.sh install

# For GUI apps
./scripts/brew-sync.sh install --file=homebrew/Brewfile.gui

# For dev tools
./scripts/brew-sync.sh install --file=homebrew/Brewfile.dev
```

### 11. Machine-Specific Configuration

```bash
# Create machine profile (use your hostname)
MACHINE=$(hostname -s)
mkdir -p machines/$MACHINE

# Create machine-specific git config
cat > machines/$MACHINE/.gitconfig.local << 'EOF'
[user]
    email = your.work@email.com
EOF

# Create machine-specific zsh config
cat > machines/$MACHINE/.zshrc.local << 'EOF'
# Machine-specific zsh config
# Add aliases, PATH additions, etc.
EOF

# Link machine configs
ln -sf ~/dotfiles/machines/$MACHINE/.gitconfig.local ~/.gitconfig.local
mkdir -p ~/.config/zsh
ln -sf ~/dotfiles/machines/$MACHINE/.zshrc.local ~/.config/zsh/local.zsh
```

### 12. macOS Preferences (Optional)

```bash
# Review what will change first
cat macos/defaults.sh

# Apply preferences
./macos/defaults.sh
```

## Testing After Installation

Run through these checks to verify everything works:

```bash
# Git
git config --list --show-origin | head -20
git status  # in any repo

# Shell (in a NEW terminal)
echo $SHELL
alias | head -10
which fzf

# SSH
ssh -T git@github.com

# Homebrew
brew doctor

# Symlinks - verify they point to dotfiles
ls -la ~/.zshrc ~/.gitconfig ~/.config/git/ignore
```

## Rollback Procedures

### Quick Rollback (Single Package)

If one component is broken:

```bash
# 1. Unlink the broken package
./scripts/stow-link.sh zsh unlink

# 2. Restore from the most recent backup
cp ~/dotfiles/backups/latest/.zshrc ~/.zshrc
cp ~/dotfiles/backups/latest/.zshenv ~/.zshenv

# 3. Restart shell
exec zsh
```

### Full Rollback (Everything)

If multiple things are broken:

```bash
# 1. Unlink all packages
for pkg in git gh nvim ssh python vscode zsh; do
    ./scripts/stow-link.sh "$pkg" unlink 2>/dev/null || true
done

# 2. Find your backup
ls ~/dotfiles/backups/

# 3. Restore everything from a specific backup
rsync -av ~/dotfiles/backups/YYYY-MM-DD_HH-MM-SS_pre-setup/ ~/

# 4. Restart shell
exec zsh
```

### Emergency Recovery

If your terminal won't open at all:

1. Open **Terminal.app** (not iTerm2) — it may use a different shell config
2. Or press Cmd+Space, type "Terminal", press Enter
3. Run: `mv ~/.zshrc ~/.zshrc.broken && cp ~/dotfiles/backups/latest/.zshrc ~/.zshrc`
4. Open a new terminal window

## Syncing to Another Machine

### On the New Machine

```bash
# 1. Install prerequisites
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
brew install stow git

# 2. Clone repo
git clone https://github.com/YOUR_USERNAME/dotfiles.git ~/dotfiles
cd ~/dotfiles

# 3. Back up existing configs
./scripts/backup.sh pre-sync ~/.zshrc ~/.zshenv ~/.gitconfig ~/.ssh/config ~/.config

# 4. Set up variables for this machine
cp templates/variables.env.example variables.env
# Edit with this machine's specific values

# 5. Run installer
./scripts/install.sh

# 6. Set up machine-specific configs
MACHINE=$(hostname -s)
mkdir -p machines/$MACHINE
# Create .gitconfig.local, .zshrc.local as needed
```

### Pulling Updates

When you've pushed changes from another machine:

```bash
cd ~/dotfiles

# Back up first
./scripts/backup.sh pre-pull ~/.zshrc ~/.gitconfig

# Pull changes
git pull origin main

# Symlinks auto-update (they point to the repo files)
# Open a new terminal to pick up any shell changes

# If new packages were added, stow them:
./scripts/stow-link.sh NEW_PACKAGE link
```

## Maintenance

### Weekly Routine

```bash
cd ~/dotfiles

# Update Brewfile from current system
./scripts/brew-sync.sh dump

# Review and commit changes
git diff
git add -A
git commit -m "Weekly sync: update configs"
git push
```

### Adding a New Tool's Config

```bash
# 1. Create package directory mirroring $HOME structure
mkdir -p ~/dotfiles/newtool/.config/newtool

# 2. Copy config into it
cp ~/.config/newtool/config.toml ~/dotfiles/newtool/.config/newtool/

# 3. Stow it
./scripts/stow-link.sh newtool link

# 4. Commit
git add newtool/
git commit -m "Add newtool config"
git push
```

## Troubleshooting

See [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) for common issues.

**Most common problems**:

- **Stow conflict**: An existing file blocks the symlink. Run `./scripts/stow-link.sh PACKAGE check` to see conflicts. The `link` action backs them up automatically.
- **Terminal broken after zsh stow**: Rollback with `./scripts/stow-link.sh zsh unlink` then restore from `backups/latest/`.
- **Template not rendered**: Make sure `variables.env` exists and has all required values. Run `./scripts/install.sh` to re-render.
- **SSH permission denied**: Run `chmod 700 ~/.ssh && chmod 600 ~/.ssh/config`.
