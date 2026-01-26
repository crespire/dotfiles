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

info()  { printf "${GREEN}[INFO]${NC} %s\n" "$1"; }
warn()  { printf "${YELLOW}[WARN]${NC} %s\n" "$1"; }

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
  # Linux: Build from source
  # Ensure dependencies are installed (git and bash should be present from utils.sh)
  if ! command -v git >/dev/null 2>&1; then
    warn "git is required but not installed. Please install git first."
    exit 1
  fi

  if ! command -v make >/dev/null 2>&1; then
    info "Installing make (required for building asdf)..."
    sudo apt-get -y install make
  fi

  if command -v asdf >/dev/null 2>&1; then
    INSTALLED_VERSION=$(asdf version 2>/dev/null | head -1)
    info "asdf already installed (${INSTALLED_VERSION})"
  else
    info "Installing asdf ${ASDF_VERSION} from source..."

    # Create temp directory for build
    ASDF_BUILD_DIR=$(mktemp -d)
    cd "$ASDF_BUILD_DIR"

    # Clone the specific version
    git clone https://github.com/asdf-vm/asdf.git --branch "$ASDF_VERSION" --depth 1

    # Build
    cd asdf
    make

    # Install binary to ~/.local/bin (user-writable, commonly on PATH)
    mkdir -p "$HOME/.local/bin"
    cp bin/asdf "$HOME/.local/bin/asdf"
    chmod +x "$HOME/.local/bin/asdf"

    # Cleanup
    cd "$HOME"
    rm -rf "$ASDF_BUILD_DIR"

    info "asdf installed to ~/.local/bin/asdf"

    # Ensure ~/.local/bin is on PATH for this session
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
	local name="$1"
	local url="$2"
	if asdf plugin list | grep -q "^${name}$"; then
		echo "Plugin $name already installed"
	else
		echo "Adding plugin $name..."
		asdf plugin add "$name" "$url"
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
