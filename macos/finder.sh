#!/usr/bin/env bash
set -euo pipefail

# Finder Preferences - idempotent

defaults write NSGlobalDomain AppleShowAllExtensions -bool true
echo "  Finder: show all file extensions"

defaults write com.apple.finder AppleShowAllFiles -bool true
echo "  Finder: show hidden files"

defaults write com.apple.finder ShowPathbar -bool true
echo "  Finder: path bar enabled"

defaults write com.apple.finder ShowStatusBar -bool true
echo "  Finder: status bar enabled"

defaults write com.apple.finder FXPreferredViewStyle -string "Nlsv"
echo "  Finder: default view set to list"

defaults write com.apple.finder FXDefaultSearchScope -string "SCcf"
echo "  Finder: search scoped to current folder"

defaults write com.apple.finder FXEnableExtensionChangeWarning -bool false
echo "  Finder: extension change warning disabled"
