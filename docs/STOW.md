# GNU Stow Usage

GNU Stow creates symlinks from package directories into `$HOME`, keeping your actual config files in the dotfiles repo.

## How It Works

Each stow package is a top-level directory whose contents mirror `$HOME`:

```
git/
  .gitconfig                -> ~/.gitconfig
  .config/
    git/
      ignore                -> ~/.config/git/ignore
```

Running `stow git` from `~/dotfiles` creates these symlinks automatically.

## Common Commands

Run all commands from `~/dotfiles/`:

```bash
# Create symlinks
stow git                    # Stow a single package
stow git zsh nvim           # Stow multiple packages

# Remove symlinks
stow -D git                 # Unstow a package

# Restow (remove + create, useful after restructuring)
stow -R git

# Dry run (preview without changes)
stow -n git                 # Preview what would happen
stow -nv git                # Preview with verbose output
```

## The stow-link.sh Wrapper

The wrapper script adds safety checks on top of raw stow:

```bash
./scripts/stow-link.sh git check      # Show symlink status and conflicts
./scripts/stow-link.sh git simulate   # Dry run via stow --no
./scripts/stow-link.sh git link       # Back up conflicts, then stow
./scripts/stow-link.sh git unlink     # Remove symlinks
```

The `link` action automatically backs up any existing files that would conflict.

## Package Structure

Packages must mirror the `$HOME` directory structure. Files ending in `.template` and `README.md` are skipped during stow operations.

Not all directories are stow packages. `homebrew/`, `macos/`, `scripts/`, `machines/`, `docs/`, and `templates/` contain scripts or data, not symlinked configs.

## Troubleshooting

### Conflict: Existing File

```
WARNING! stowing git would cause conflicts:
  * existing target is neither a link nor a directory: .gitconfig
```

Fix: Use the wrapper (handles backup automatically):
```bash
./scripts/stow-link.sh git link
```

Or manually:
```bash
mv ~/.gitconfig ~/.gitconfig.bak
stow git
```

### Broken Symlinks

Find broken symlinks:
```bash
find ~ -maxdepth 3 -xtype l 2>/dev/null
```

Fix by restowing: `stow -R git`

### Adopt Existing Files

To pull an existing config into the repo:
```bash
stow --adopt git
```

This moves `~/.gitconfig` into `git/.gitconfig` and creates the symlink. Review the diff afterwards.
