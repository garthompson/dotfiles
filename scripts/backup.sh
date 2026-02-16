#!/usr/bin/env bash
set -euo pipefail

# backup.sh - Create timestamped backups of config files before changes
#
# Usage: ./scripts/backup.sh <context> <files...>
# Example: ./scripts/backup.sh pre-stow ~/.zshrc ~/.gitconfig ~/.config/git

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
BACKUPS_ROOT="$DOTFILES_DIR/backups"

# ---------------------------------------------------------------------------
# Color helpers (disabled when output is not a terminal)
# ---------------------------------------------------------------------------
if [[ -t 1 ]]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[0;33m'
    BOLD='\033[1m'
    RESET='\033[0m'
else
    RED='' GREEN='' YELLOW='' BOLD='' RESET=''
fi

info()    { printf "${GREEN}%s${RESET}\n" "$*"; }
warn()    { printf "${YELLOW}WARNING: %s${RESET}\n" "$*" >&2; }
error()   { printf "${RED}ERROR: %s${RESET}\n" "$*" >&2; }

# ---------------------------------------------------------------------------
# Usage
# ---------------------------------------------------------------------------
usage() {
    cat <<EOF
Usage: $(basename "$0") <context> <file|dir> [file|dir ...]

Arguments:
  context   A label for this backup (e.g. pre-stow, weekly, pre-pull)
  file|dir  One or more files or directories to back up

Example:
  $(basename "$0") pre-stow ~/.zshrc ~/.gitconfig ~/.config/git
EOF
}

if [[ $# -lt 2 ]]; then
    error "Expected at least 2 arguments (context + one or more files)."
    usage
    exit 1
fi

CONTEXT="$1"
shift
FILES=("$@")

# Sanitise context label
if [[ ! "$CONTEXT" =~ ^[a-zA-Z0-9._-]+$ ]]; then
    error "Context label must contain only alphanumerics, dots, hyphens, or underscores."
    exit 1
fi

# ---------------------------------------------------------------------------
# Disk space check (warn only)
# ---------------------------------------------------------------------------
check_disk_space() {
    local avail_gb
    avail_gb=$(df -g "$DOTFILES_DIR" | awk 'NR==2 {print $4}')
    if [[ -n "$avail_gb" ]] && [[ "$avail_gb" -lt 1 ]]; then
        warn "Less than 1 GB free on the volume (${avail_gb} GB available)."
    fi
}

check_disk_space

# ---------------------------------------------------------------------------
# Create backup directory
# ---------------------------------------------------------------------------
TIMESTAMP="$(date '+%Y-%m-%d_%H-%M-%S')"
BACKUP_DIR="$BACKUPS_ROOT/${TIMESTAMP}_${CONTEXT}"

if ! mkdir -p "$BACKUP_DIR"; then
    error "Failed to create backup directory: $BACKUP_DIR"
    exit 1
fi

# ---------------------------------------------------------------------------
# Back up each file / directory
# ---------------------------------------------------------------------------
MANIFEST="$BACKUP_DIR/manifest.txt"
TOTAL_BYTES=0
BACKED_UP=0
SKIPPED=0

{
    printf "# Backup manifest\n"
    printf "# Created: %s\n" "$(date)"
    printf "# Context: %s\n" "$CONTEXT"
    printf "#\n"
    printf "# %-60s  %10s  %s\n" "PATH" "SIZE" "TYPE"
    printf "# %s\n" "$(printf '%.0s-' {1..80})"
} > "$MANIFEST"

for src in "${FILES[@]}"; do
    # Expand tilde
    src="${src/#\~/$HOME}"

    # Resolve to absolute path
    if [[ "$src" == /* ]]; then
        abs="$src"
    else
        abs="$(cd "$(dirname "$src")" 2>/dev/null && pwd)/$(basename "$src")" || abs="$src"
    fi

    # Skip missing files
    if [[ ! -e "$abs" && ! -L "$abs" ]]; then
        warn "Skipping (does not exist): $abs"
        printf "  %-60s  %10s  %s\n" "$abs" "-" "MISSING" >> "$MANIFEST"
        ((SKIPPED++)) || true
        continue
    fi

    # Path relative to $HOME
    if [[ "$abs" == "$HOME"/* ]]; then
        rel="${abs#$HOME/}"
    else
        rel="${abs#/}"
    fi

    dest="$BACKUP_DIR/$rel"
    mkdir -p "$(dirname "$dest")"

    # Copy preserving symlinks and permissions
    if [[ -d "$abs" ]]; then
        if ! cp -a "$abs" "$dest"; then
            error "Failed to copy directory: $abs"
            exit 1
        fi
        dir_size=$(du -sk "$abs" | awk '{print $1}')
        size_bytes=$((dir_size * 1024))
        TOTAL_BYTES=$((TOTAL_BYTES + size_bytes))
        printf "  %-60s  %10s  %s\n" "$rel" "${dir_size}K" "directory" >> "$MANIFEST"
    elif [[ -L "$abs" ]]; then
        cp -a "$abs" "$dest"
        link_target="$(readlink "$abs")"
        printf "  %-60s  %10s  %s\n" "$rel" "-" "symlink -> $link_target" >> "$MANIFEST"
    elif [[ -f "$abs" ]]; then
        if ! cp -a "$abs" "$dest"; then
            error "Failed to copy file: $abs"
            exit 1
        fi
        size_bytes=$(stat -f %z "$abs")
        TOTAL_BYTES=$((TOTAL_BYTES + size_bytes))
        printf "  %-60s  %10s  %s\n" "$rel" "${size_bytes}B" "file" >> "$MANIFEST"
    else
        warn "Skipping (unsupported type): $abs"
        printf "  %-60s  %10s  %s\n" "$rel" "-" "UNSUPPORTED" >> "$MANIFEST"
        ((SKIPPED++)) || true
        continue
    fi

    ((BACKED_UP++)) || true
done

# ---------------------------------------------------------------------------
# Update the "latest" symlink
# ---------------------------------------------------------------------------
LATEST_LINK="$BACKUPS_ROOT/latest"
rm -f "$LATEST_LINK"
ln -s "$BACKUP_DIR" "$LATEST_LINK"

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
if [[ $TOTAL_BYTES -ge 1048576 ]]; then
    TOTAL_HUMAN="$(awk "BEGIN {printf \"%.1f MB\", $TOTAL_BYTES/1048576}")"
elif [[ $TOTAL_BYTES -ge 1024 ]]; then
    TOTAL_HUMAN="$(awk "BEGIN {printf \"%.1f KB\", $TOTAL_BYTES/1024}")"
else
    TOTAL_HUMAN="${TOTAL_BYTES} bytes"
fi

echo ""
printf "${BOLD}Backup complete${RESET}\n"
info "  Location : $BACKUP_DIR"
info "  Items    : $BACKED_UP backed up, $SKIPPED skipped"
info "  Size     : $TOTAL_HUMAN"
info "  Latest   : $LATEST_LINK -> $(basename "$BACKUP_DIR")"
echo ""
