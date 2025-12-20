#!/bin/sh

OS="${OS:-$(uname -s)}"
ARCH="${ARCH:-$(uname -m)}"

if [ "$OS" = "Darwin" ]; then
  # Use Homebrew on macOS
  brew tap austinliuigi/brew-neovim-nightly https://github.com/austinliuigi/brew-neovim-nightly.git
  brew install neovim-nightly

elif [ "$OS" = "Linux" ]; then
  # Install via github package for Linux
  if [ "$ARCH" = "x86_64" ]; then
    NVIM_PKG="nvim-linux-x86_64"
  elif [ "$ARCH" = "aarch64" ]; then
    NVIM_PKG="nvim-linux-arm64"
  else
    echo "Unsupported architecture: $ARCH"
    exit 1
  fi

  curl -LO "https://github.com/neovim/neovim/releases/latest/download/${NVIM_PKG}.tar.gz"
  sudo rm -rf "/opt/${NVIM_PKG}"
  sudo tar -C /opt -xzf "${NVIM_PKG}.tar.gz"
  rm "${NVIM_PKG}.tar.gz"

  # Add to PATH hint
  echo "Add to your PATH: export PATH=\"/opt/${NVIM_PKG}/bin:\$PATH\""
fi

printf "Neovim installed!\n"
