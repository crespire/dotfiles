#!/bin/sh

# =============================================================================
# Neovim Installation
# =============================================================================

OS="${OS:-$(uname -s)}"
ARCH="${ARCH:-$(uname -m)}"

# Colors (inherit from parent or define)
GREEN="${GREEN:-\033[0;32m}"
YELLOW="${YELLOW:-\033[1;33m}"
RED="${RED:-\033[0;31m}"
NC="${NC:-\033[0m}"

info()  { printf "${GREEN}[INFO]${NC} %s\n" "$1"; }
warn()  { printf "${YELLOW}[WARN]${NC} %s\n" "$1"; }
error() { printf "${RED}[ERROR]${NC} %s\n" "$1"; }

if [ "$OS" = "Darwin" ]; then
  # Use Homebrew on macOS
  if brew list neovim-nightly >/dev/null 2>&1; then
    info "Neovim nightly already installed via Homebrew, updating..."
    brew upgrade neovim-nightly || true
  else
    info "Installing Neovim nightly via Homebrew..."
    brew tap austinliuigi/brew-neovim-nightly https://github.com/austinliuigi/brew-neovim-nightly.git
    brew install neovim-nightly
  fi

elif [ "$OS" = "Linux" ]; then
  # Install via github package for Linux
  if [ "$ARCH" = "x86_64" ]; then
    NVIM_PKG="nvim-linux-x86_64"
  elif [ "$ARCH" = "aarch64" ]; then
    NVIM_PKG="nvim-linux-arm64"
  else
    error "Unsupported architecture: $ARCH"
    exit 1
  fi

  INSTALL_NVIM=false
  if command -v nvim >/dev/null 2>&1; then
    INSTALLED_VERSION=$(nvim --version | head -1)
    LATEST_VERSION=$(curl -fsSL -o /dev/null -w '%{url_effective}' "https://github.com/neovim/neovim/releases/latest" | grep -o '[^/]*$')
    if echo "$INSTALLED_VERSION" | grep -q "$LATEST_VERSION"; then
      info "Neovim ${LATEST_VERSION} already installed, skipping."
    else
      info "Neovim version differs (installed: ${INSTALLED_VERSION}, latest: ${LATEST_VERSION}), updating..."
      INSTALL_NVIM=true
    fi
  else
    INSTALL_NVIM=true
  fi

  if [ "$INSTALL_NVIM" = true ]; then
    info "Installing Neovim from GitHub releases..."
    curl -LO "https://github.com/neovim/neovim/releases/latest/download/${NVIM_PKG}.tar.gz"
    sudo rm -rf "/opt/${NVIM_PKG}"
    sudo tar -C /opt -xzf "${NVIM_PKG}.tar.gz"
    rm "${NVIM_PKG}.tar.gz"

    if ! command -v nvim >/dev/null 2>&1; then
      warn "Neovim installed to /opt/${NVIM_PKG}/bin"
      warn "Add to your shell config: export PATH=\"/opt/${NVIM_PKG}/bin:\$PATH\""
    fi
  fi
fi

info "Neovim installed!"
