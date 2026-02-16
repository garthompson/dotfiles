# New Machine Setup

Step-by-step guide for setting up dotfiles on a fresh Mac.

## Prerequisites

1. **Homebrew** (also installs Xcode Command Line Tools):
   ```bash
   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
   ```

2. **GNU Stow**:
   ```bash
   brew install stow
   ```

3. **Git** (usually included with Xcode CLI tools):
   ```bash
   git --version
   ```

## Clone the Repository

```bash
git clone https://github.com/YOUR_USERNAME/dotfiles.git ~/dotfiles
cd ~/dotfiles
```

## Configure Variables

```bash
cp templates/variables.env.example variables.env
```

Edit `variables.env` with your values:
- `GIT_NAME` and `GIT_EMAIL` for git commits
- SSH key paths for work and personal keys
- Python venv path for Neovim integration

## Run the Installer

```bash
./scripts/install.sh
```

The installer will:
1. Detect existing configurations
2. Check prerequisites (brew, stow)
3. Walk through each component interactively
4. Render templates from `variables.env`
5. Create symlinks via GNU Stow
6. Set up machine-specific configuration

## Manual Alternative

If you prefer to install components individually:

```bash
# Back up existing configs first
./scripts/backup.sh pre-setup ~/.zshrc ~/.gitconfig ~/.ssh/config

# Install one package at a time
./scripts/stow-link.sh git link
./scripts/stow-link.sh zsh link
# etc.
```

## Set Up Machine Profile

```bash
MACHINE=$(hostname -s)
mkdir -p machines/$MACHINE

# Create and edit machine-specific configs
# See machines/README.md for details
```

## Verify

After installation, open a new terminal and check:

```bash
git config user.name         # Should show your name
alias | head -5              # Should show your aliases
echo $PATH                   # Should include expected paths
ssh -T git@github.com        # Should authenticate
```

## Next Steps

- Use the system for a week before syncing to other machines
- Run `./scripts/brew-sync.sh dump` to capture your Homebrew packages
- Commit and push changes: `git add -A && git commit -m "Initial setup" && git push`
