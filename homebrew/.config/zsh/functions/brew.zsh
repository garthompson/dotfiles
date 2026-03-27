# Wrap brew to auto-update Brewfile on install/uninstall
brew() {
  command brew "$@"
  local ret=$?
  if [[ $ret -eq 0 && ($1 == "install" || $1 == "uninstall" || $1 == "remove") ]]; then
    local brewfile="${DOTFILES_BREWFILE:-$HOME/dotfiles/homebrew/Brewfile}"
    echo "Updating $brewfile..."
    _brewfile_update "$brewfile"
  fi
  return $ret
}

# Regenerate Brewfile using only top-level packages
_brewfile_update() {
  local brewfile="$1"
  local tmpfile="$(mktemp)"

  # Taps
  command brew tap | while read -r tap; do
    echo "tap \"$tap\""
  done > "$tmpfile"
  echo >> "$tmpfile"

  # Formulae (leaves only)
  command brew leaves | while read -r formula; do
    local desc="$(command brew desc --eval-all "$formula" 2>/dev/null | cut -d: -f2- | sed 's/^ //')"
    if [[ -n "$desc" ]]; then
      echo "# $desc"
    fi
    echo "brew \"$formula\""
  done >> "$tmpfile"
  echo >> "$tmpfile"

  # Casks
  command brew list --cask | while read -r cask; do
    local desc="$(command brew desc --eval-all --cask "$cask" 2>/dev/null | cut -d: -f2- | sed 's/^ //')"
    if [[ -n "$desc" ]]; then
      echo "# $desc"
    fi
    echo "cask \"$cask\""
  done >> "$tmpfile"
  echo >> "$tmpfile"

  # VS Code extensions
  if command -v code >/dev/null 2>&1; then
    code --list-extensions 2>/dev/null | while read -r ext; do
      echo "vscode \"$ext\""
    done >> "$tmpfile"
  fi

  mv "$tmpfile" "$brewfile"
  echo "Brewfile updated with $(command brew leaves | wc -l | tr -d ' ') formulae."
}
