#!/bin/sh

if command -v brew; then
	brew tap austinliuigi/brew-neovim-nightly https://github.com/austinliuigi/brew-neovim-nightly.git
	brew install neovim-nightly
else
	# Add PPA for Unstable (nightly)
	sudo add-apt-repository -y ppa:neovim-ppa/unstable
	sudo apt -y install neovim
fi

. "$HOME/.zshrc"
nvim --headless
