#!/bin/sh

if command -v brew; then
  brew tap austinliuigi/brew-neovim-nightly https://github.com/austinliuigi/brew-neovim-nightly.git
  brew install neovim-nightly
else
  # Install via github package
  curl -LO https://github.com/neovim/neovim/releases/latest/download/nvim-linux-x86_64.tar.gz
  sudo rm -rf /opt/nvim-linux-x86_64
  sudo tar -C /opt -xzf nvim-linux-x86_64.tar.gz
  sudo rm nvim-linux-x86_64.tar.gz
fi

printf "Neovim installed!\n"
