#!/bin/sh

# Utilities - install development dependencies based on OS

OS="${OS:-$(uname -s)}"
ARCH="${ARCH:-$(uname -m)}"

if [ "$OS" = "Darwin" ]; then
  echo "Installing macOS dependencies via Homebrew..."
  brew install openssl libyaml zlib ripgrep postgresql fd

elif [ "$OS" = "Linux" ]; then
  echo "Installing Linux dependencies via apt..."
  sudo apt-get -y update && sudo apt-get -y upgrade
  sudo apt-get -y install software-properties-common
  sudo apt-get -y install build-essential
  sudo apt-get -y install libssl-dev
  sudo apt-get -y install libyaml-dev
  sudo apt-get -y install zlib1g zlib1g-dev
  sudo apt-get -y install ripgrep
  sudo apt-get -y install postgresql postgresql-contrib libpq-dev
  sudo apt-get -y install fd-find
fi

# Install Lazygit
echo "Installing Lazygit..."
if [ "$OS" = "Darwin" ]; then
  brew install lazygit
else
  LAZYGIT_VERSION=$(curl -s "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" | grep -Po '"tag_name": "v\K[^"]*')
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
echo "Installed Lazygit!"

# Install fzf
if [ ! -d ~/.fzf ]; then
  git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf
  ~/.fzf/install --all --no-bash --no-fish
else
  echo "fzf already installed, skipping..."
fi

# Install Jetbrains Mono Nerdfonts
echo "Downloading JetBrains Mono Nerd Font..."
FONT_VERSION="v3.1.1"
if [ "$OS" = "Darwin" ]; then
  FONT_DIR="$HOME/Library/Fonts"
  mkdir -p "$FONT_DIR"
  curl -Lo JetBrainsMono.zip "https://github.com/ryanoasis/nerd-fonts/releases/download/${FONT_VERSION}/JetBrainsMono.zip"
  unzip -o JetBrainsMono.zip -d "$FONT_DIR"
  rm JetBrainsMono.zip
else
  FONT_DIR="$HOME/.fonts"
  mkdir -p "$FONT_DIR"
  curl -Lo JetBrainsMono.zip "https://github.com/ryanoasis/nerd-fonts/releases/download/${FONT_VERSION}/JetBrainsMono.zip"
  unzip -o JetBrainsMono.zip -d "$FONT_DIR"
  fc-cache -fv
  rm JetBrainsMono.zip
fi
echo "Installed JetBrains Mono Nerd Font!"

# Go Lint
# sudo curl -sSfL https://raw.githubusercontent.com/golangci/golangci-lint/master/install.sh | sh -s -- -b $(go env GOPATH)/bin v1.52.2
