#!/usr/bin/env bash
set -euo pipefail

# Dock Preferences - idempotent

defaults write com.apple.dock autohide -bool true
echo "  Dock: auto-hide enabled"

defaults write com.apple.dock tilesize -int 40
echo "  Dock: tile size set to 40"

defaults write com.apple.dock mineffect -string "scale"
echo "  Dock: minimize effect set to scale"

defaults write com.apple.dock show-recents -bool false
echo "  Dock: recent apps hidden"

defaults write com.apple.dock show-process-indicators -bool true
echo "  Dock: indicator lights for open apps enabled"
