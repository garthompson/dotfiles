#!/usr/bin/env bash
set -euo pipefail

# macOS System Preferences - idempotent, safe to run multiple times

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "This will change macOS system preferences. Continue? [y/N]"
read -r response
if [[ ! "$response" =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 0
fi

echo "Applying macOS system preferences..."

# --- Dock ---
echo ""
echo "--- Dock preferences ---"
source "$SCRIPT_DIR/dock.sh"

# --- Finder ---
echo ""
echo "--- Finder preferences ---"
source "$SCRIPT_DIR/finder.sh"

# --- Screenshots ---
echo ""
echo "--- Screenshot preferences ---"
mkdir -p "$HOME/Desktop"
defaults write com.apple.screencapture location -string "$HOME/Desktop"
defaults write com.apple.screencapture type -string "png"
defaults write com.apple.screencapture disable-shadow -bool true
echo "  Screenshots: save to ~/Desktop, format png, shadow disabled"

# --- Keyboard ---
echo ""
echo "--- Keyboard preferences ---"
defaults write NSGlobalDomain KeyRepeat -int 2
defaults write NSGlobalDomain InitialKeyRepeat -int 15
echo "  Key repeat rate set to 2, initial delay set to 15"

# --- Trackpad ---
echo ""
echo "--- Trackpad preferences ---"
defaults write com.apple.AppleMultitouchTrackpad Clicking -bool true
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad Clicking -bool true
defaults -currentHost write NSGlobalDomain com.apple.mouse.tapBehavior -int 1
echo "  Tap to click enabled"

# --- General UI ---
echo ""
echo "--- General UI preferences ---"
defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode -bool true
defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode2 -bool true
echo "  Save panel expanded by default"
defaults write NSGlobalDomain PMPrintingExpandedStateForPrint -bool true
defaults write NSGlobalDomain PMPrintingExpandedStateForPrint2 -bool true
echo "  Print panel expanded by default"

# --- Security ---
echo ""
echo "--- Security preferences ---"
defaults write com.apple.screensaver askForPassword -int 1
defaults write com.apple.screensaver askForPasswordDelay -int 0
echo "  Password required immediately after sleep/screensaver"

# --- Restart affected applications ---
echo ""
echo "Restarting affected applications..."
for app in "Dock" "Finder" "SystemUIServer"; do
    killall "$app" &>/dev/null || true
done
echo "  Restarted Dock, Finder, SystemUIServer"

# --- Summary ---
echo ""
echo "=============================="
echo "  macOS preferences applied"
echo "=============================="
echo ""
echo "Changes applied:"
echo "  - Dock: auto-hide, tile size 40, scale effect, no recent apps"
echo "  - Finder: show extensions/hidden files, path bar, status bar, list view"
echo "  - Screenshots: ~/Desktop, png, no shadow"
echo "  - Keyboard: fast key repeat"
echo "  - Trackpad: tap to click"
echo "  - General: expanded save/print panels"
echo "  - Security: immediate password on sleep"
echo ""
echo "Some changes may require logout/restart to take full effect."
