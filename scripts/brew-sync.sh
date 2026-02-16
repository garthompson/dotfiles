#!/usr/bin/env bash
set -euo pipefail

# brew-sync.sh - Manage Homebrew packages for a dotfiles repository
#
# Usage: ./scripts/brew-sync.sh <mode> [--file=path]
# Modes: dump, diff, install

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# ---------------------------------------------------------------------------
# Color helpers
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

info()    { printf "${BLUE}%s${RESET}\n" "$*"; }
success() { printf "${GREEN}%s${RESET}\n" "$*"; }
warn()    { printf "${YELLOW}%s${RESET}\n" "$*"; }
error()   { printf "${RED}%s${RESET}\n" "$*" >&2; }

# ---------------------------------------------------------------------------
# Validation
# ---------------------------------------------------------------------------
if ! command -v brew &>/dev/null; then
    error "Error: Homebrew is not installed."
    error "Install it from https://brew.sh and try again."
    exit 1
fi

# ---------------------------------------------------------------------------
# Parse arguments
# ---------------------------------------------------------------------------
MODE=""
BREWFILE_OVERRIDE=""

for arg in "$@"; do
    case "$arg" in
        --file=*)
            BREWFILE_OVERRIDE="${arg#--file=}"
            ;;
        dump|diff|install)
            MODE="$arg"
            ;;
        -h|--help)
            printf "Usage: %s <dump|diff|install> [--file=path]\n" "$(basename "$0")"
            printf "\nModes:\n"
            printf "  dump     Export current Homebrew packages to a Brewfile\n"
            printf "  diff     Show what would change (packages to add/remove)\n"
            printf "  install  Show diff, prompt, then install from Brewfile\n"
            printf "\nOptions:\n"
            printf "  --file=PATH  Brewfile path (default: DOTFILES_DIR/homebrew/Brewfile)\n"
            exit 0
            ;;
        *)
            error "Error: Unknown argument '$arg'"
            printf "Usage: %s <dump|diff|install> [--file=path]\n" "$(basename "$0")" >&2
            exit 1
            ;;
    esac
done

if [[ -z "$MODE" ]]; then
    error "Error: No mode specified."
    printf "Usage: %s <dump|diff|install> [--file=path]\n" "$(basename "$0")" >&2
    exit 1
fi

# ---------------------------------------------------------------------------
# Resolve Brewfile path
# ---------------------------------------------------------------------------
resolve_brewfile_path() {
    local path="${1:-}"
    if [[ -z "$path" ]]; then
        printf "%s/homebrew/Brewfile" "$DOTFILES_DIR"
        return
    fi
    if [[ "$path" == /* ]]; then
        printf "%s" "$path"
    else
        printf "%s/%s" "$DOTFILES_DIR" "$path"
    fi
}

BREWFILE_PATH="$(resolve_brewfile_path "$BREWFILE_OVERRIDE")"

# ---------------------------------------------------------------------------
# dump mode
# ---------------------------------------------------------------------------
do_dump() {
    local target_path="$BREWFILE_PATH"
    local target_dir
    target_dir="$(dirname "$target_path")"

    if [[ ! -d "$target_dir" ]]; then
        info "Creating directory: ${target_dir}"
        mkdir -p "$target_dir"
    fi

    info "Dumping Homebrew packages to: ${target_path}"
    brew bundle dump --describe --force --file="$target_path"

    local formulae casks taps vscode
    formulae=$(grep -c '^brew ' "$target_path" 2>/dev/null || true)
    casks=$(grep -c '^cask ' "$target_path" 2>/dev/null || true)
    taps=$(grep -c '^tap ' "$target_path" 2>/dev/null || true)
    vscode=$(grep -c '^vscode ' "$target_path" 2>/dev/null || true)

    success "Brewfile written successfully."
    printf "\n"
    printf "  ${BOLD}Formulae :${RESET} %s\n" "$formulae"
    printf "  ${BOLD}Casks    :${RESET} %s\n" "$casks"
    printf "  ${BOLD}Taps     :${RESET} %s\n" "$taps"
    printf "  ${BOLD}VS Code  :${RESET} %s\n" "$vscode"
}

# ---------------------------------------------------------------------------
# diff mode - returns 0 if changes exist, 1 if in sync
# ---------------------------------------------------------------------------
do_diff() {
    local brewfile="$BREWFILE_PATH"

    if [[ ! -f "$brewfile" ]]; then
        error "Error: Brewfile not found at ${brewfile}"
        error "Run '$(basename "$0") dump' first, or specify --file=."
        exit 1
    fi

    info "Checking Brewfile: ${brewfile}"
    printf "\n"

    if brew bundle check --file="$brewfile" &>/dev/null; then
        success "Everything in the Brewfile is already installed."

        local brewfile_packages installed_packages extras
        brewfile_packages="$(brew bundle list --formula --file="$brewfile" 2>/dev/null | sort || true)"
        installed_packages="$(brew list --formula -1 | sort)"
        extras="$(comm -13 <(echo "$brewfile_packages") <(echo "$installed_packages") || true)"

        if [[ -n "$extras" ]]; then
            local extra_count
            extra_count="$(echo "$extras" | wc -l | tr -d ' ')"
            warn "Packages installed but NOT in Brewfile (${extra_count}):"
            echo "$extras" | while read -r pkg; do
                printf "  ${YELLOW}%-40s${RESET} (not in Brewfile)\n" "$pkg"
            done
            printf "\n"
            info "Note: These will NOT be removed (no --cleanup)."
        fi

        return 1
    fi

    local brewfile_packages installed_packages
    brewfile_packages="$(brew bundle list --formula --file="$brewfile" 2>/dev/null | sort || true)"
    installed_packages="$(brew list --formula -1 | sort)"

    local missing extras
    missing="$(comm -23 <(echo "$brewfile_packages") <(echo "$installed_packages") || true)"
    extras="$(comm -13 <(echo "$brewfile_packages") <(echo "$installed_packages") || true)"

    local brewfile_casks installed_casks missing_casks extra_casks
    brewfile_casks="$(brew bundle list --cask --file="$brewfile" 2>/dev/null | sort || true)"
    installed_casks="$(brew list --cask -1 2>/dev/null | sort || true)"
    missing_casks="$(comm -23 <(echo "$brewfile_casks") <(echo "$installed_casks") || true)"
    extra_casks="$(comm -13 <(echo "$brewfile_casks") <(echo "$installed_casks") || true)"

    local has_changes=false

    if [[ -n "$missing" ]]; then
        has_changes=true
        local missing_count
        missing_count="$(echo "$missing" | wc -l | tr -d ' ')"
        printf "${GREEN}${BOLD}Formulae to install (${missing_count}):${RESET}\n"
        echo "$missing" | while read -r pkg; do
            printf "  ${GREEN}+ %s${RESET}\n" "$pkg"
        done
        printf "\n"
    fi

    if [[ -n "$missing_casks" ]]; then
        has_changes=true
        local missing_cask_count
        missing_cask_count="$(echo "$missing_casks" | wc -l | tr -d ' ')"
        printf "${GREEN}${BOLD}Casks to install (${missing_cask_count}):${RESET}\n"
        echo "$missing_casks" | while read -r pkg; do
            printf "  ${GREEN}+ %s${RESET}\n" "$pkg"
        done
        printf "\n"
    fi

    if [[ -n "$extras" ]]; then
        local extra_count
        extra_count="$(echo "$extras" | wc -l | tr -d ' ')"
        printf "${YELLOW}${BOLD}Formulae installed but NOT in Brewfile (${extra_count}):${RESET}\n"
        echo "$extras" | while read -r pkg; do
            printf "  ${YELLOW}~ %s${RESET}\n" "$pkg"
        done
        printf "\n"
    fi

    if [[ -n "$extras" || -n "$extra_casks" ]]; then
        info "Note: Extra packages will NOT be removed (no --cleanup)."
        printf "\n"
    fi

    if [[ "$has_changes" == true ]]; then
        return 0
    else
        return 1
    fi
}

# ---------------------------------------------------------------------------
# install mode
# ---------------------------------------------------------------------------
do_install() {
    local brewfile="$BREWFILE_PATH"

    if [[ ! -f "$brewfile" ]]; then
        error "Error: Brewfile not found at ${brewfile}"
        error "Run '$(basename "$0") dump' first, or specify --file=."
        exit 1
    fi

    if ! do_diff; then
        success "Nothing to install. System is up to date with the Brewfile."
        return 0
    fi

    printf "${BOLD}Proceed with installation? [y/N]:${RESET} "
    read -r answer
    if [[ "$answer" != "y" && "$answer" != "Y" ]]; then
        warn "Aborted."
        exit 0
    fi

    printf "\n"
    info "Installing packages from: ${brewfile}"
    printf "\n"

    brew bundle install --file="$brewfile"

    printf "\n"
    success "Installation complete."
    info "Run '$(basename "$0") diff --file=${brewfile}' to verify."
}

# ---------------------------------------------------------------------------
# Main dispatch
# ---------------------------------------------------------------------------
case "$MODE" in
    dump)    do_dump ;;
    diff)    do_diff || true ;;
    install) do_install ;;
esac
