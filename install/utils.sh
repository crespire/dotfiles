#!/bin/sh

# =============================================================================
# Utilities - install development dependencies based on OS
# =============================================================================

OS="${OS:-$(uname -s)}"
ARCH="${ARCH:-$(uname -m)}"

# Colors (inherit from parent or define)
GREEN="${GREEN:-\033[0;32m}"
YELLOW="${YELLOW:-\033[1;33m}"
NC="${NC:-\033[0m}"

info()  { printf "${GREEN}[INFO]${NC} %s\n" "$1"; }
warn()  { printf "${YELLOW}[WARN]${NC} %s\n" "$1"; }

# =============================================================================
# System Dependencies
# =============================================================================
if [ "$OS" = "Darwin" ]; then
  info "Installing macOS dependencies via Homebrew..."
  brew install openssl libyaml zlib ripgrep postgresql fd unzip

elif [ "$OS" = "Linux" ]; then
  info "Installing Linux dependencies via apt..."
  sudo apt-get -y update && sudo apt-get -y upgrade
  sudo apt-get -y install software-properties-common
  sudo apt-get -y install build-essential
  sudo apt-get -y install libssl-dev
  sudo apt-get -y install libyaml-dev
  sudo apt-get -y install zlib1g zlib1g-dev
  sudo apt-get -y install ripgrep
  sudo apt-get -y install postgresql postgresql-contrib libpq-dev
  sudo apt-get -y install fd-find
  sudo apt-get -y install unzip
  sudo apt-get -y install fontconfig  # for fc-cache
  sudo apt-get -y install git curl bash  # ensure git, curl, and bash are available (bash required for asdf)
fi

# =============================================================================
# Lazygit
# =============================================================================
if command -v lazygit >/dev/null 2>&1; then
  info "Lazygit already installed, skipping..."
else
  info "Installing Lazygit..."
  if [ "$OS" = "Darwin" ]; then
    brew install lazygit
  else
    # Use sed instead of grep -P for portability
    LAZYGIT_VERSION=$(curl -s "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" | sed -n 's/.*"tag_name": "v\([^"]*\)".*/\1/p')
    if [ "$ARCH" = "x86_64" ]; then
      LAZYGIT_ARCH="Linux_x86_64"
    elif [ "$ARCH" = "aarch64" ]; then
      LAZYGIT_ARCH="Linux_arm64"
    else
      LAZYGIT_ARCH="Linux_x86_64"
    fi
    curl -Lo lazygit.tar.gz "https://github.com/jesseduffield/lazygit/releases/latest/download/lazygit_${LAZYGIT_VERSION}_${LAZYGIT_ARCH}.tar.gz"
    tar xf lazygit.tar.gz lazygit
    sudo install lazygit /usr/local/bin
    rm lazygit lazygit.tar.gz
  fi
  info "Lazygit installed!"
fi

# =============================================================================
# fzf
# =============================================================================
if [ -d ~/.fzf ]; then
  info "fzf already installed, skipping..."
else
  info "Installing fzf..."
  git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf
  ~/.fzf/install --all --no-bash --no-fish
  info "fzf installed!"
fi

# =============================================================================
# JetBrains Mono Nerd Font
# =============================================================================
FONT_VERSION="v3.1.1"

if [ "$OS" = "Darwin" ]; then
  FONT_DIR="$HOME/Library/Fonts"
  FONT_CHECK="$FONT_DIR/JetBrainsMonoNerdFont-Regular.ttf"
else
  FONT_DIR="$HOME/.fonts"
  FONT_CHECK="$FONT_DIR/JetBrainsMonoNerdFont-Regular.ttf"
fi

if [ -f "$FONT_CHECK" ]; then
  info "JetBrains Mono Nerd Font already installed, skipping..."
else
  info "Installing JetBrains Mono Nerd Font..."
  mkdir -p "$FONT_DIR"
  curl -Lo JetBrainsMono.zip "https://github.com/ryanoasis/nerd-fonts/releases/download/${FONT_VERSION}/JetBrainsMono.zip"
  unzip -o JetBrainsMono.zip -d "$FONT_DIR"
  rm JetBrainsMono.zip

  if [ "$OS" = "Linux" ]; then
    fc-cache -fv
  fi
  info "JetBrains Mono Nerd Font installed!"
fi

# =============================================================================
# Optional: Go Lint
# =============================================================================
# sudo curl -sSfL https://raw.githubusercontent.com/golangci/golangci-lint/master/install.sh | sh -s -- -b $(go env GOPATH)/bin v1.52.2

info "Utilities installation complete!"
