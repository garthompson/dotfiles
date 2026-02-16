# Troubleshooting

## Stow Conflicts

**Symptom**: Stow refuses to link because a file already exists.

**Fix**: Use the wrapper which backs up automatically:
```bash
./scripts/stow-link.sh git link
```

Or manually:
```bash
mv ~/.gitconfig ~/.gitconfig.bak
stow git
```

## Broken Symlinks

**Symptom**: Config file exists but points to nothing.

**Find them**:
```bash
find ~ -maxdepth 3 -xtype l 2>/dev/null
```

**Fix**: Remove and restow:
```bash
rm ~/.broken_link
stow -R git
```

## Zsh Not Loading After Stow

1. Verify symlink: `ls -la ~/.zshrc`
2. Check login shell: `echo $SHELL` (should be zsh)
3. Source manually to see errors: `source ~/.zshrc`
4. Check local config exists if sourced: `ls -la ~/.config/zsh/local.zsh`

## Homebrew Bundle Issues

**Check status**:
```bash
brew bundle check --file=~/dotfiles/homebrew/Brewfile
```

**Common causes**:
- Cask requires Rosetta: `softwareupdate --install-rosetta`
- Tap renamed or removed: update the Brewfile
- Formula removed: `brew search <name>` for alternatives

## Template Not Rendered

1. Check `variables.env` exists: `cat ~/dotfiles/variables.env`
2. Re-run installer: `./scripts/install.sh`
3. Missing variable = unreplaced `{{PLACEHOLDER}}` in output

## SSH Permission Denied

```bash
chmod 700 ~/.ssh
chmod 600 ~/.ssh/config
chmod 600 ~/.ssh/id_*
```

## Rollback

### Quick (single package)

```bash
./scripts/stow-link.sh zsh unlink
cp ~/dotfiles/backups/latest/.zshrc ~/.zshrc
exec zsh
```

### Full (everything)

```bash
# Unlink all
for pkg in git gh nvim ssh python vscode zsh; do
    ./scripts/stow-link.sh "$pkg" unlink 2>/dev/null || true
done

# Restore from backup
ls ~/dotfiles/backups/
rsync -av ~/dotfiles/backups/TIMESTAMP/ ~/
exec zsh
```

### Emergency (terminal won't open)

1. Open Terminal.app (not iTerm2)
2. Run: `mv ~/.zshrc ~/.zshrc.broken`
3. Run: `cp ~/dotfiles/backups/latest/.zshrc ~/.zshrc`
4. Open a new terminal
