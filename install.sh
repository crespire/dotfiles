#!/bin/bash

# Set failure mode
set -eEuo pipefail

# This sets the following:
# e = exit on a non-zero status code
# E = inherit traps on ERR, unsure tbh.
# u = treat unset variables as errors, so we exit setup if there is an issue
# o = run an option, in this case "pipefail" returns the last command to exit
#     with non-zero status, returns 0 if all commands in the pipeline are a
#     success.

# =============================================================================
# Colors and Logging
# =============================================================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

info()  { printf "${GREEN}[INFO]${NC} %s\n" "$1"; }
warn()  { printf "${YELLOW}[WARN]${NC} %s\n" "$1"; }
error() { printf "${RED}[ERROR]${NC} %s\n" "$1"; }
step()  { printf "${BLUE}[STEP]${NC} %s\n" "$1"; }

# =============================================================================
# Dry Run Mode
# =============================================================================
DRY_RUN=false

if [[ "${1:-}" == "--dry-run" ]] || [[ "${1:-}" == "-n" ]]; then
  DRY_RUN=true
  warn "Dry run mode - no changes will be made"
fi

if [[ "${1:-}" == "--help" ]] || [[ "${1:-}" == "-h" ]]; then
  echo "Usage: ./install.sh [OPTIONS]"
  echo ""
  echo "Options:"
  echo "  --dry-run, -n    Show what would be done without making changes"
  echo "  --help, -h       Show this help message"
  exit 0
fi

# Helper to run commands (respects dry-run)
run() {
  if [[ "$DRY_RUN" == true ]]; then
    info "[DRY RUN] Would run: $*"
  else
    "$@"
  fi
}

# =============================================================================
# Helper Functions
# =============================================================================
link_if_exists() {
  local src="$1"
  local dest="$2"
  if [[ ! -e "$src" ]]; then
    warn "Skipping symlink: $src (not found)"
    return
  fi
  # Skip if destination already resolves to the same path as source
  if [[ -e "$dest" ]] && [[ "$(readlink -f "$src")" == "$(readlink -f "$dest")" ]]; then
    info "Already linked: $dest"
    return
  fi
  run ln -sfnv "$src" "$dest"
}

# =============================================================================
# Start Installation
# =============================================================================
info "Let's install some stuff..."

# Detect OS
OS="$(uname -s)"
ARCH="$(uname -m)"
export OS ARCH

if [[ "$OS" == "Darwin" ]]; then
  step "Detected macOS ($ARCH)"

  # Install Homebrew if not present
  if ! command -v brew &> /dev/null; then
    info "Installing Homebrew..."
    if [[ "$DRY_RUN" == false ]]; then
      /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

      # Add brew to path for Apple Silicon
      if [[ "$ARCH" == "arm64" ]]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
      else
        eval "$(/usr/local/bin/brew shellenv)"
      fi
    else
      info "[DRY RUN] Would install Homebrew"
    fi
  else
    info "Homebrew already installed"
  fi

  # curl is pre-installed on macOS
  # zsh is the default shell on modern macOS, but ensure it's there
  # git comes with Xcode CLT but brew version is more recent
  run brew install git zsh || true

elif [[ "$OS" == "Linux" ]]; then
  step "Detected Linux ($ARCH)"

  # Install essential utilities first
  run sudo apt -y install curl git

  # Install zsh
  run sudo apt -y install zsh
fi

# Set zsh as default shell (skip if already using zsh)
if [[ "$SHELL" == *"zsh"* ]]; then
  info "zsh is already the default shell"
else
  info "Setting zsh as default shell..."
  run chsh -s "$(which zsh)"
fi

# =============================================================================
# Environment Setup
# =============================================================================
DOTFILES_DIR="$HOME/.dotfiles"
ZDOTDIR="$HOME/.dotfiles/.config/zsh/"
export DOTFILES_DIR DOTFILES_CACHE DOTFILES_EXTRA_DIR ZDOTDIR
# DOTFILES_CACHE="$DOTFILES_DIR/.cache.sh"

# Set up Bitwarden env vars if not present
#if [[ -z "${BW_CLIENTID}" ]]; then
#  echo "Bitwarden client id: "
#  read -n BW_CLIENTID
#  export BW_CLIENTID="$BW_CLIENTID"
#fi
#if [[ -z "${BW_CLIENTSECRET}" ]]; then
#  echo "Bitwarden client secret: "
#  read -n BW_CLIENTSECRET
#  export BW_CLIENTSECRET="$BW_CLIENTSECRET"
#fi

# Make utilities available
# Once we have some utilities we can add them to ~/.dotfiles/bin as executable
# PATH="$DOTFILES_DIR/bin:$PATH"

# =============================================================================
# Symlinks
# =============================================================================
step "Setting up symlinks..."

# Zsh config files -> home directory
link_if_exists "$DOTFILES_DIR/.config/zsh/.zshrc" "$HOME/.zshrc"
link_if_exists "$DOTFILES_DIR/.config/zsh/.zprofile" "$HOME/.zprofile"
link_if_exists "$DOTFILES_DIR/.config/zsh/.zsh_aliases" "$HOME/.zsh_aliases"
link_if_exists "$DOTFILES_DIR/.config/zsh/.zsh_funcs" "$HOME/.zsh_funcs"

# Other dotfiles -> home directory
link_if_exists "$DOTFILES_DIR/.config/.asdfrc" "$HOME/.asdfrc"
link_if_exists "$DOTFILES_DIR/.config/.rubocop.yml" "$HOME/.rubocop.yml"
link_if_exists "$DOTFILES_DIR/git/.gitconfig" "$HOME/.gitconfig"
link_if_exists "$DOTFILES_DIR/lang-defaults/.default-gems" "$HOME/.default-gems"
link_if_exists "$DOTFILES_DIR/lang-defaults/.default-npm-packages" "$HOME/.default-npm-packages"

# XDG config directory - create if needed and symlink specific items
run mkdir -p "$HOME/.config"
link_if_exists "$DOTFILES_DIR/.config/nvim" "$HOME/.config/nvim"
# Add other XDG config symlinks here as needed:
# link_if_exists "$DOTFILES_DIR/.config/alacritty" "$HOME/.config/alacritty"
# link_if_exists "$DOTFILES_DIR/.config/kitty" "$HOME/.config/kitty"

# Claude Code configuration
link_if_exists "$DOTFILES_DIR/.config/.claude" "$HOME/.claude"

# =============================================================================
# Install Packages
# =============================================================================
if [[ "$DRY_RUN" == false ]]; then
  step "Installing utilities..."
  source "$DOTFILES_DIR/install/utils.sh"

  step "Installing Neovim..."
  source "$DOTFILES_DIR/install/nvim.sh"

  step "Installing asdf and language runtimes..."
  source "$DOTFILES_DIR/install/asdf_install.sh"
else
  info "[DRY RUN] Would source install/utils.sh"
  info "[DRY RUN] Would source install/nvim.sh"
  info "[DRY RUN] Would source install/asdf_install.sh"
fi

# =============================================================================
# Finish
# =============================================================================
info "Installation complete! 🎉"
info "Restart your terminal or run: source \$HOME/.zshrc"
