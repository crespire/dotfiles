#!/bin/bash

# Add PPA for Unstable (nightly)
sudo add-apt-repository -y ppa:neovim-ppa/unstable
sudo apt -y install neovim

. "$HOME/.bashrc"
nvim --headless
