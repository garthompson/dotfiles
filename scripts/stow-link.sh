#!/usr/bin/env bash
set -euo pipefail

# stow-link.sh - GNU Stow wrapper with safety checks for dotfiles
#
# Usage: ./scripts/stow-link.sh <package> <action>
# Actions: check, simulate, link, unlink
# Example: ./scripts/stow-link.sh git link

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# ---------------------------------------------------------------------------
# Color output
# ---------------------------------------------------------------------------
if [[ -t 1 ]]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[0;33m'
    BLUE='\033[0;34m'
    BOLD='\033[1m'
    RESET='\033[0m'
else
    RED='' GREEN='' YELLOW='' BLUE='' BOLD='' RESET=''
fi

info()    { printf "${BLUE}[info]${RESET}  %s\n" "$*"; }
success() { printf "${GREEN}[ok]${RESET}    %s\n" "$*"; }
warn()    { printf "${YELLOW}[warn]${RESET}  %s\n" "$*"; }
error()   { printf "${RED}[error]${RESET} %s\n" "$*" >&2; }

usage() {
    cat <<EOF
Usage: $(basename "$0") <package> <action>

Actions:
  check    - Show what would be linked and detect conflicts
  simulate - Dry-run (stow --no), show what stow would do
  link     - Back up conflicts, create symlinks, verify
  unlink   - Remove symlinks, verify removal

Example:
  $(basename "$0") git link
EOF
    exit 1
}

# ---------------------------------------------------------------------------
# Validation
# ---------------------------------------------------------------------------
validate_prerequisites() {
    local package="$1"

    if ! command -v stow &>/dev/null; then
        error "GNU Stow is not installed."
        error "Install it with: brew install stow"
        exit 1
    fi

    local pkg_dir="$DOTFILES_DIR/$package"
    if [[ ! -d "$pkg_dir" ]]; then
        error "Package directory not found: $pkg_dir"
        error "Available packages:"
        for d in "$DOTFILES_DIR"/*/; do
            local name
            name="$(basename "$d")"
            [[ "$name" == "scripts" || "$name" == "backups" || "$name" == "docs" || "$name" == "templates" || "$name" == "machines" || "$name" == "homebrew" || "$name" == "macos" ]] && continue
            printf "  %s\n" "$name" >&2
        done
        exit 1
    fi

    # Check package has stowable files
    local has_files=false
    while IFS= read -r -d '' file; do
        local rel="${file#"$pkg_dir"/}"
        [[ "$rel" == *.template ]] && continue
        [[ "$(basename "$rel")" == "README.md" ]] && continue
        has_files=true
        break
    done < <(find "$pkg_dir" -type f -print0 2>/dev/null)

    if [[ "$has_files" == false ]]; then
        error "Package '$package' has no stowable files (empty or only .template/README.md)."
        exit 1
    fi
}

# Collect stowable files in a package (skips .template and README.md)
collect_package_files() {
    local pkg_dir="$1"
    while IFS= read -r -d '' file; do
        local rel="${file#"$pkg_dir"/}"
        [[ "$rel" == *.template ]] && continue
        [[ "$(basename "$rel")" == "README.md" ]] && continue
        printf '%s\n' "$rel"
    done < <(find "$pkg_dir" -type f -print0 2>/dev/null | sort -z)
}

# ---------------------------------------------------------------------------
# check
# ---------------------------------------------------------------------------
declare -a CHECK_CONFLICTS=()
declare -a CHECK_ALREADY=()
declare -a CHECK_FREE=()

do_check() {
    local package="$1"
    local pkg_dir="$DOTFILES_DIR/$package"

    CHECK_CONFLICTS=()
    CHECK_ALREADY=()
    CHECK_FREE=()

    info "Checking package '${BOLD}$package${RESET}' ..."
    echo ""

    local files
    files="$(collect_package_files "$pkg_dir")"

    if [[ -z "$files" ]]; then
        warn "No stowable files found in $pkg_dir"
        return
    fi

    while IFS= read -r rel; do
        local target="$HOME/$rel"
        local source="$pkg_dir/$rel"

        if [[ -L "$target" ]]; then
            local resolved
            resolved="$(cd "$(dirname "$target")" && realpath "$(readlink "$target")" 2>/dev/null)" || resolved=""
            if [[ "$resolved" == "$source" ]]; then
                CHECK_ALREADY+=("$rel")
                printf "  ${GREEN}%-12s${RESET} %s\n" "[linked]" "$rel"
            else
                CHECK_CONFLICTS+=("$rel")
                printf "  ${RED}%-12s${RESET} %s  (symlink -> %s)\n" "[conflict]" "$rel" "$(readlink "$target")"
            fi
        elif [[ -e "$target" ]]; then
            CHECK_CONFLICTS+=("$rel")
            printf "  ${YELLOW}%-12s${RESET} %s\n" "[conflict]" "$rel"
        else
            CHECK_FREE+=("$rel")
            printf "  ${BLUE}%-12s${RESET} %s\n" "[free]" "$rel"
        fi
    done <<< "$files"

    echo ""
    info "Summary: ${#CHECK_ALREADY[@]} already linked, ${#CHECK_FREE[@]} free, ${#CHECK_CONFLICTS[@]} conflicts"
}

# ---------------------------------------------------------------------------
# simulate
# ---------------------------------------------------------------------------
do_simulate() {
    local package="$1"

    info "Simulating stow for package '${BOLD}$package${RESET}' ..."
    echo ""

    stow --no --verbose=2 \
        --dir="$DOTFILES_DIR" \
        --target="$HOME" \
        "$package" 2>&1 || true

    echo ""
    success "Simulation complete (no changes were made)."
}

# ---------------------------------------------------------------------------
# link
# ---------------------------------------------------------------------------
do_link() {
    local package="$1"
    local pkg_dir="$DOTFILES_DIR/$package"

    do_check "$package"

    local total_files
    total_files="$(collect_package_files "$pkg_dir" | wc -l | tr -d ' ')"

    # Already fully linked
    if [[ ${#CHECK_ALREADY[@]} -eq $total_files && $total_files -gt 0 ]]; then
        echo ""
        success "Package '$package' is already fully linked. Nothing to do."
        return 0
    fi

    # Handle conflicts: back up and remove
    if [[ ${#CHECK_CONFLICTS[@]} -gt 0 ]]; then
        echo ""
        warn "Found ${#CHECK_CONFLICTS[@]} conflicting file(s). Backing up ..."

        local conflict_paths=()
        for rel in "${CHECK_CONFLICTS[@]}"; do
            conflict_paths+=("$HOME/$rel")
        done

        local backup_script="$DOTFILES_DIR/scripts/backup.sh"
        if [[ -x "$backup_script" ]]; then
            "$backup_script" "pre-stow-$package" "${conflict_paths[@]}"
        else
            warn "backup.sh not found or not executable. Creating simple backup."
            local backup_dir="$DOTFILES_DIR/backups/pre-stow-${package}-$(date +%Y%m%d-%H%M%S)"
            mkdir -p "$backup_dir"
            for rel in "${CHECK_CONFLICTS[@]}"; do
                local target="$HOME/$rel"
                local dest="$backup_dir/$rel"
                mkdir -p "$(dirname "$dest")"
                cp -a "$target" "$dest"
            done
            success "Backup complete: $backup_dir"
        fi

        # Remove conflicting files
        for rel in "${CHECK_CONFLICTS[@]}"; do
            rm -f "$HOME/$rel"
            info "  Removed: $HOME/$rel"
        done
        echo ""
    fi

    # Run stow
    info "Stowing package '$package' ..."
    if ! stow --verbose --dir="$DOTFILES_DIR" --target="$HOME" "$package" 2>&1; then
        error "stow failed for package '$package'."
        exit 1
    fi

    echo ""

    # Verify symlinks
    local verified=0 failed=0

    while IFS= read -r rel; do
        local target="$HOME/$rel"
        local source="$pkg_dir/$rel"

        if [[ -L "$target" ]]; then
            local resolved
            resolved="$(cd "$(dirname "$target")" && realpath "$(readlink "$target")" 2>/dev/null)" || resolved=""
            if [[ "$resolved" == "$source" ]]; then
                ((verified++))
            else
                warn "Symlink exists but points elsewhere: $target"
                ((failed++))
            fi
        else
            error "Expected symlink was not created: $target"
            ((failed++))
        fi
    done <<< "$(collect_package_files "$pkg_dir")"

    echo ""
    if [[ $failed -eq 0 ]]; then
        success "Package '$package' linked successfully ($verified file(s))."
    else
        warn "Package '$package' linked with issues: $verified OK, $failed failed."
        exit 1
    fi
}

# ---------------------------------------------------------------------------
# unlink
# ---------------------------------------------------------------------------
do_unlink() {
    local package="$1"
    local pkg_dir="$DOTFILES_DIR/$package"

    info "Unlinking package '${BOLD}$package${RESET}' ..."
    echo ""

    if ! stow -D --verbose --dir="$DOTFILES_DIR" --target="$HOME" "$package" 2>&1; then
        error "stow -D failed for package '$package'."
        exit 1
    fi

    echo ""

    local removed=0 remaining=0

    while IFS= read -r rel; do
        local target="$HOME/$rel"
        local source="$pkg_dir/$rel"

        if [[ -L "$target" ]]; then
            local resolved
            resolved="$(cd "$(dirname "$target")" && realpath "$(readlink "$target")" 2>/dev/null)" || resolved=""
            if [[ "$resolved" == "$source" ]]; then
                warn "Symlink still exists: $target"
                ((remaining++))
            else
                ((removed++))
            fi
        else
            ((removed++))
        fi
    done <<< "$(collect_package_files "$pkg_dir")"

    echo ""
    if [[ $remaining -eq 0 ]]; then
        success "Package '$package' unlinked successfully ($removed file(s))."
    else
        warn "Package '$package' partially unlinked: $removed removed, $remaining still linked."
        exit 1
    fi

    info "Note: Backup files are NOT auto-restored. Restore manually if needed."
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
if [[ $# -lt 2 ]]; then
    usage
fi

PACKAGE="$1"
ACTION="$2"

validate_prerequisites "$PACKAGE"

case "$ACTION" in
    check)    do_check "$PACKAGE" ;;
    simulate) do_simulate "$PACKAGE" ;;
    link)     do_link "$PACKAGE" ;;
    unlink)   do_unlink "$PACKAGE" ;;
    *)
        error "Unknown action: $ACTION"
        echo ""
        usage
        ;;
esac
