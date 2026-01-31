#!/bin/sh

# =============================================================================
# asdf Installation and Language Runtimes
# =============================================================================

ASDF_VERSION="v0.18.0"
OS="${OS:-$(uname -s)}"

# Colors (inherit from parent or define)
GREEN="${GREEN:-\033[0;32m}"
YELLOW="${YELLOW:-\033[1;33m}"
NC="${NC:-\033[0m}"

info() { printf "${GREEN}[INFO]${NC} %s\n" "$1"; }
warn() { printf "${YELLOW}[WARN]${NC} %s\n" "$1"; }

# =============================================================================
# Install asdf based on OS
# =============================================================================
if [ "$OS" = "Darwin" ]; then
  # macOS: Install via Homebrew
  if command -v asdf >/dev/null 2>&1; then
    info "asdf already installed via Homebrew, updating..."
    brew upgrade asdf || true
  else
    info "Installing asdf via Homebrew..."
    brew install asdf
  fi

  # Source asdf for this session (Homebrew location)
  if [ -f /opt/homebrew/opt/asdf/libexec/asdf.sh ]; then
    . /opt/homebrew/opt/asdf/libexec/asdf.sh
  elif [ -f /usr/local/opt/asdf/libexec/asdf.sh ]; then
    . /usr/local/opt/asdf/libexec/asdf.sh
  fi

elif [ "$OS" = "Linux" ]; then
  # Linux: Install pre-built binary
  ARCH=$(uname -m)
  case "$ARCH" in
    x86_64)  RELEASE_ARCH="amd64" ;;
    aarch64) RELEASE_ARCH="arm64" ;;
    *)       warn "Unsupported architecture: $ARCH"; exit 1 ;;
  esac

  INSTALL_ASDF=false
  if command -v asdf >/dev/null 2>&1; then
    INSTALLED_VERSION=$(asdf version 2>/dev/null | head -1)
    if [ "$INSTALLED_VERSION" = "$ASDF_VERSION" ]; then
      info "asdf ${ASDF_VERSION} already installed, skipping."
    else
      info "asdf version differs (installed: ${INSTALLED_VERSION}, wanted: ${ASDF_VERSION}), updating..."
      INSTALL_ASDF=true
    fi
  else
    INSTALL_ASDF=true
  fi

  if [ "$INSTALL_ASDF" = true ]; then
    info "Installing asdf ${ASDF_VERSION} pre-built binary..."

    TARBALL="asdf-${ASDF_VERSION}-linux-${RELEASE_ARCH}.tar.gz"
    DOWNLOAD_URL="https://github.com/asdf-vm/asdf/releases/download/${ASDF_VERSION}/${TARBALL}"

    cd "$HOME" || exit
    curl -fsSL -o "$TARBALL" "$DOWNLOAD_URL"

    mkdir -p "$HOME/.local/bin"
    tar -xzf "$TARBALL" -C "$HOME/.local/bin" asdf
    chmod +x "$HOME/.local/bin/asdf"

    rm -f "$TARBALL"

    info "asdf installed to ~/.local/bin/asdf"
    export PATH="$HOME/.local/bin:$PATH"
  fi

  # Verify installation
  if command -v asdf >/dev/null 2>&1; then
    info "asdf is available: $(asdf version)"
  else
    warn "asdf installation may have failed. Please check ~/.local/bin is on your PATH."
    exit 1
  fi
else
  warn "Unsupported OS: $OS"
  exit 1
fi

# Helper to add plugin idempotently
add_plugin() {
  plugin_name="$1"
  plugin_url="$2"
  if asdf plugin list | grep -q "^${plugin_name}$"; then
    echo "Plugin $plugin_name already installed"
  else
    echo "Adding plugin $plugin_name..."
    asdf plugin add "$plugin_name" "$plugin_url"
  fi
}

# =============================================================================
# Ruby
# =============================================================================
echo "Setting up Ruby..."
add_plugin ruby https://github.com/asdf-vm/asdf-ruby.git
asdf install ruby latest
asdf global ruby latest

# =============================================================================
# Node.js
# =============================================================================
echo "Setting up Node.js..."
add_plugin nodejs https://github.com/asdf-vm/asdf-nodejs.git
asdf install nodejs latest
asdf global nodejs latest

# =============================================================================
# Yarn
# =============================================================================
echo "Setting up Yarn..."
add_plugin yarn https://github.com/twuni/asdf-yarn
asdf install yarn 1.22.22
asdf global yarn 1.22.22

# =============================================================================
# Go
# =============================================================================
echo "Setting up Go..."
add_plugin golang https://github.com/kennyp/asdf-golang
asdf install golang latest
asdf global golang latest

echo "All language runtimes installed!"
