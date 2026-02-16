#!/usr/bin/env bash
set -euo pipefail

# install.sh - Interactive dotfiles installation orchestrator
#
# Usage: ./scripts/install.sh

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

info()    { printf "${BLUE}[info]${RESET}    %s\n" "$*"; }
warn()    { printf "${YELLOW}[warn]${RESET}    %s\n" "$*"; }
error()   { printf "${RED}[error]${RESET}   %s\n" "$*"; }
success() { printf "${GREEN}[ok]${RESET}      %s\n" "$*"; }

# ---------------------------------------------------------------------------
# Utility functions
# ---------------------------------------------------------------------------

# ask_yn PROMPT DEFAULT - returns 0 for yes, 1 for no
ask_yn() {
    local prompt="$1"
    local default="${2:-n}"
    local hint

    if [[ "$default" == "y" ]]; then
        hint="[Y/n]"
    else
        hint="[y/N]"
    fi

    while true; do
        printf "${BOLD}%s %s${RESET} " "$prompt" "$hint"
        read -r reply </dev/tty
        reply="${reply:-$default}"
        case "$reply" in
            [Yy]*) return 0 ;;
            [Nn]*) return 1 ;;
            *)     echo "Please answer y or n." ;;
        esac
    done
}

check_command() {
    command -v "$1" &>/dev/null
}

# ---------------------------------------------------------------------------
# Template rendering
# ---------------------------------------------------------------------------
VARIABLES_ENV="$DOTFILES_DIR/variables.env"
VARIABLES_EXAMPLE="$DOTFILES_DIR/templates/variables.env.example"

ensure_variables_env() {
    if [[ -f "$VARIABLES_ENV" ]]; then
        return 0
    fi

    if [[ -f "$VARIABLES_EXAMPLE" ]]; then
        warn "variables.env not found. Copying from templates/variables.env.example ..."
        cp "$VARIABLES_EXAMPLE" "$VARIABLES_ENV"
    else
        warn "Neither variables.env nor templates/variables.env.example found."
        warn "Creating a blank variables.env."
        touch "$VARIABLES_ENV"
    fi

    error "Please fill in $VARIABLES_ENV with your values, then re-run this script."
    exit 1
}

# render_template TEMPLATE_FILE OUTPUT_FILE
render_template() {
    local template_file="$1"
    local output_file="$2"

    if [[ ! -f "$template_file" ]]; then
        error "Template not found: $template_file"
        return 1
    fi

    # Read variables into associative array
    declare -A vars
    while IFS='=' read -r key value; do
        [[ -z "$key" || "$key" =~ ^[[:space:]]*# ]] && continue
        key="$(echo "$key" | xargs)"
        # Strip surrounding quotes from value
        value="$(echo "$value" | xargs)"
        value="${value#\"}"
        value="${value%\"}"
        vars["$key"]="$value"
    done < "$VARIABLES_ENV"

    local content
    content="$(<"$template_file")"

    # Replace each {{VAR}} placeholder
    for key in "${!vars[@]}"; do
        content="${content//\{\{$key\}\}/${vars[$key]}}"
    done

    # Warn about unreplaced placeholders
    local remaining
    remaining="$(echo "$content" | grep -oE '\{\{[A-Za-z_][A-Za-z_0-9]*\}\}' || true)"
    if [[ -n "$remaining" ]]; then
        warn "Unreplaced placeholders in $output_file:"
        echo "$remaining" | sort -u | while read -r ph; do
            warn "  $ph"
        done
    fi

    mkdir -p "$(dirname "$output_file")"
    printf '%s\n' "$content" > "$output_file"
    success "Rendered $template_file -> $output_file"
}

# ---------------------------------------------------------------------------
# Tracking
# ---------------------------------------------------------------------------
declare -a INSTALLED=()
declare -a SKIPPED=()
declare -a FAILED=()

track_installed() { INSTALLED+=("$1"); }
track_skipped()   { SKIPPED+=("$1"); }
track_failed()    { FAILED+=("$1"); }

# ---------------------------------------------------------------------------
# Welcome and state detection
# ---------------------------------------------------------------------------
welcome() {
    echo ""
    printf "${BOLD}======================================${RESET}\n"
    printf "${BOLD}  Dotfiles Installer${RESET}\n"
    printf "${BOLD}======================================${RESET}\n"
    echo ""
    info "Dotfiles directory: $DOTFILES_DIR"
    echo ""
}

detect_state() {
    local hostname_val
    hostname_val="$(hostname -s 2>/dev/null || hostname)"
    local os_version
    os_version="$(sw_vers -productName 2>/dev/null || echo "Unknown") $(sw_vers -productVersion 2>/dev/null || echo "")"

    info "Hostname:   $hostname_val"
    info "OS:         $os_version"
    echo ""

    printf "${BOLD}Existing configs:${RESET}\n"
    for path in ~/.zshrc ~/.gitconfig ~/.config/nvim ~/.ssh/config; do
        if [[ -e "$path" ]]; then
            if [[ -L "$path" ]]; then
                info "  $path  (symlink -> $(readlink "$path"))"
            else
                warn "  $path  (regular file - will be backed up if overwritten)"
            fi
        else
            info "  $path  (not found)"
        fi
    done
    echo ""

    printf "${BOLD}Prerequisites:${RESET}\n"
    for cmd in git brew stow; do
        if check_command "$cmd"; then
            success "  $cmd  $(command -v "$cmd")"
        else
            warn "  $cmd  NOT FOUND"
        fi
    done
    echo ""
}

install_prerequisites() {
    if ! check_command brew; then
        if ask_yn "Homebrew is not installed. Install it now?" "y"; then
            info "Installing Homebrew..."
            /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
            if [[ -f /opt/homebrew/bin/brew ]]; then
                eval "$(/opt/homebrew/bin/brew shellenv)"
            elif [[ -f /usr/local/bin/brew ]]; then
                eval "$(/usr/local/bin/brew shellenv)"
            fi
            if check_command brew; then
                success "Homebrew installed."
            else
                error "Homebrew installation failed."
            fi
        else
            warn "Skipping Homebrew. Some components may not work."
        fi
    fi

    if ! check_command stow; then
        if check_command brew; then
            if ask_yn "GNU Stow is not installed. Install via Homebrew?" "y"; then
                brew install stow
                if check_command stow; then
                    success "stow installed."
                else
                    error "stow installation failed."
                fi
            else
                warn "Skipping stow. Symlinking will not work."
            fi
        else
            warn "stow is missing and brew is unavailable."
        fi
    fi
    echo ""
}

# ---------------------------------------------------------------------------
# Component installers
# ---------------------------------------------------------------------------

install_git() {
    info "Setting up Git..."
    local tpl="$DOTFILES_DIR/git/.gitconfig.template"
    local out="$DOTFILES_DIR/git/.gitconfig"

    if [[ -f "$tpl" ]]; then
        render_template "$tpl" "$out" || return 1
    else
        warn "No git template found - skipping render."
    fi

    "$SCRIPT_DIR/stow-link.sh" git link || return 1

    local name
    name="$(git config user.name 2>/dev/null || true)"
    if [[ -n "$name" ]]; then
        success "Git configured. user.name = $name"
    else
        warn "git config user.name is not set."
    fi
}

install_gh() {
    info "Setting up GitHub CLI..."
    "$SCRIPT_DIR/stow-link.sh" gh link || return 1
    if check_command gh; then
        success "GitHub CLI: $(gh --version | head -1)"
    else
        warn "gh command not found on PATH."
    fi
}

install_nvim() {
    info "Setting up Neovim..."
    local tpl="$DOTFILES_DIR/nvim/.config/nvim/init.vim.template"
    local out="$DOTFILES_DIR/nvim/.config/nvim/init.vim"

    if [[ -f "$tpl" ]]; then
        render_template "$tpl" "$out" || return 1
    fi

    "$SCRIPT_DIR/stow-link.sh" nvim link || return 1
    success "Neovim config linked."
}

install_ssh() {
    info "Setting up SSH..."
    local tpl="$DOTFILES_DIR/ssh/.ssh/config.template"
    local out="$DOTFILES_DIR/ssh/.ssh/config"

    if [[ -f "$tpl" ]]; then
        render_template "$tpl" "$out" || return 1
    fi

    "$SCRIPT_DIR/stow-link.sh" ssh link || return 1

    chmod 700 "$HOME/.ssh" 2>/dev/null || true
    chmod 600 "$HOME/.ssh/config" 2>/dev/null || true
    success "SSH config linked. Permissions set."
}

install_python() {
    info "Setting up Python..."
    "$SCRIPT_DIR/stow-link.sh" python link || return 1
    success "Python config linked."
}

install_vscode() {
    info "Setting up VS Code..."
    "$SCRIPT_DIR/stow-link.sh" vscode link || return 1
    success "VS Code config linked."
}

install_zsh() {
    info "Setting up Zsh..."
    "$SCRIPT_DIR/stow-link.sh" zsh link || return 1
    success "Zsh config linked."
    warn "Open a NEW terminal window to test your Zsh configuration."
}

install_brew_packages() {
    info "Checking Homebrew package differences..."
    "$SCRIPT_DIR/brew-sync.sh" diff || true

    if ask_yn "Install/sync Homebrew packages?" "n"; then
        "$SCRIPT_DIR/brew-sync.sh" install || return 1
        success "Homebrew packages synced."
    else
        return 1
    fi
}

install_macos_defaults() {
    warn "This will change macOS system preferences (Dock, Finder, keyboard, etc.)."
    if ask_yn "Apply macOS defaults?" "n"; then
        "$DOTFILES_DIR/macos/defaults.sh" || return 1
        success "macOS defaults applied."
    else
        return 1
    fi
}

# ---------------------------------------------------------------------------
# Machine-specific setup
# ---------------------------------------------------------------------------
setup_machine_local() {
    echo ""
    printf "${BOLD}Machine-specific configuration${RESET}\n"
    echo ""

    local default_machine
    default_machine="$(hostname -s 2>/dev/null || hostname)"

    printf "${BOLD}Enter machine name [%s]:${RESET} " "$default_machine"
    read -r machine_name </dev/tty
    machine_name="${machine_name:-$default_machine}"

    local machine_dir="$DOTFILES_DIR/machines/$machine_name"

    if [[ ! -d "$machine_dir" ]]; then
        info "Creating machine directory: machines/$machine_name/"
        mkdir -p "$machine_dir"
    fi

    if [[ ! -f "$machine_dir/.gitconfig.local" ]]; then
        cat > "$machine_dir/.gitconfig.local" << 'EOF'
# Machine-specific git configuration
# This file is included from ~/.gitconfig via [include]
#
# [user]
#     email = work@example.com
EOF
        info "Created machines/$machine_name/.gitconfig.local"
    fi

    if [[ ! -f "$machine_dir/.zshrc.local" ]]; then
        cat > "$machine_dir/.zshrc.local" << 'EOF'
# Machine-specific zsh configuration
# Sourced from .zshrc
#
# Add machine-specific aliases, PATH entries, etc.
EOF
        info "Created machines/$machine_name/.zshrc.local"
    fi

    if [[ ! -f "$machine_dir/.env.zsh" ]]; then
        cat > "$machine_dir/.env.zsh" << 'EOF'
# Machine-specific environment variables (git-ignored)
# Sourced from .zshrc
#
# export API_KEY="secret"
EOF
        info "Created machines/$machine_name/.env.zsh"
    fi

    # Create symlinks
    local link_target="$HOME/.gitconfig.local"
    if [[ ! -e "$link_target" ]]; then
        ln -sf "$machine_dir/.gitconfig.local" "$link_target"
        success "Linked $link_target"
    else
        warn "$link_target already exists - skipping."
    fi

    link_target="$HOME/.config/zsh/local.zsh"
    mkdir -p "$HOME/.config/zsh"
    if [[ ! -e "$link_target" ]]; then
        ln -sf "$machine_dir/.zshrc.local" "$link_target"
        success "Linked $link_target"
    else
        warn "$link_target already exists - skipping."
    fi

    track_installed "machine-local ($machine_name)"
}

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
print_summary() {
    echo ""
    printf "${BOLD}======================================${RESET}\n"
    printf "${BOLD}  Installation Summary${RESET}\n"
    printf "${BOLD}======================================${RESET}\n"
    echo ""

    if [[ ${#INSTALLED[@]} -gt 0 ]]; then
        printf "${GREEN}Installed / linked:${RESET}\n"
        for item in "${INSTALLED[@]}"; do
            printf "  + %s\n" "$item"
        done
        echo ""
    fi

    if [[ ${#SKIPPED[@]} -gt 0 ]]; then
        printf "${YELLOW}Skipped:${RESET}\n"
        for item in "${SKIPPED[@]}"; do
            printf "  - %s\n" "$item"
        done
        echo ""
    fi

    if [[ ${#FAILED[@]} -gt 0 ]]; then
        printf "${RED}Failed:${RESET}\n"
        for item in "${FAILED[@]}"; do
            printf "  ! %s\n" "$item"
        done
        echo ""
    fi

    printf "${BOLD}Next steps:${RESET}\n"
    echo "  1. Open a new terminal window to test your configuration."
    echo "  2. Edit machine-specific configs in machines/<name>/."
    echo "  3. Commit and push any changes to your dotfiles repo."
    echo ""
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
main() {
    welcome
    detect_state
    install_prerequisites
    ensure_variables_env

    echo ""
    printf "${BOLD}Component Installation${RESET}\n"
    printf "Select which components to install.\n"
    echo ""

    local -a components=(
        "git:install_git:Git configuration"
        "gh:install_gh:GitHub CLI configuration"
        "nvim:install_nvim:Neovim configuration"
        "ssh:install_ssh:SSH configuration"
        "python:install_python:Python configuration"
        "vscode:install_vscode:VS Code configuration"
        "zsh:install_zsh:Zsh shell configuration (test in new terminal)"
    )

    for entry in "${components[@]}"; do
        IFS=':' read -r name func desc <<< "$entry"

        if ask_yn "Install $desc?" "n"; then
            if $func; then
                track_installed "$name"
            else
                error "Failed to install $name."
                track_failed "$name"
            fi
        else
            track_skipped "$name"
        fi
        echo ""
    done

    if check_command brew; then
        if ask_yn "Sync Homebrew packages?" "n"; then
            if install_brew_packages; then
                track_installed "homebrew-packages"
            else
                track_skipped "homebrew-packages"
            fi
        else
            track_skipped "homebrew-packages"
        fi
        echo ""
    fi

    if [[ "$(uname)" == "Darwin" ]]; then
        if ask_yn "Configure macOS system defaults?" "n"; then
            if install_macos_defaults; then
                track_installed "macos-defaults"
            else
                track_skipped "macos-defaults"
            fi
        else
            track_skipped "macos-defaults"
        fi
        echo ""
    fi

    if ask_yn "Set up machine-specific configuration?" "y"; then
        setup_machine_local
    else
        track_skipped "machine-local"
    fi

    print_summary
}

main "$@"
