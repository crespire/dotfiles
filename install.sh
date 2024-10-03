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

printf "Let's install some stuff...\n"

# Install network fetch util
sudo apt -y install curl

# Install zsh and make shell
sudo apt -y install zsh
chsh -s $(which zsh)

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

# Set up links
# Switch to zsh on all OSes
# ln -sfv "$DOTFILES_DIR/.config/bash/.bashrc" "$HOME"
# ln -sfv "$DOTFILES_DIR/.config/bash/.bash_profile" "$HOME"
# ln -sfv "$DOTFILES_DIR/.config/bash/.bash_aliases" "$HOME"
ln -sfv "$DOTFILES_DIR/.config/zsh/.zshrc" "$HOME"
ln -sfv "$DOTFILES_DIR/.config/zsh/.zprofile" "$HOME"
ln -sfv "$DOTFILES_DIR/.config/zsh/.zsh_aliases" "$HOME"
ln -sfv "$DOTFILES_DIR/.config/zsh/.zsh_funcs" "$HOME"
ln -sfv "$DOTFILES_DIR/.config/.asdfrc" "$HOME"
ln -sfv "$DOTFILES_DIR/.config/.rubocop.yml" "$HOME"
ln -sfv "$DOTFILES_DIR/.config" "$HOME/.config"
ln -sfv "$DOTFILES_DIR/.config/nvim" "$HOME/.config/nvim"
ln -sfv "$DOTFILES_DIR/git/.gitconfig" "$HOME"
ln -sfv "$DOTFILES_DIR/lang-defaults/.default-gems" "$HOME"
ln -sfv "$DOTFILES_DIR/lang-defaults/.default-npm-packages" "$HOME"

# Install some packages
source "$DOTFILES_DIR/install/utils.sh"
source "$DOTFILES_DIR/install/nvim.sh"
source "$DOTFILES_DIR/install/asdf_install.sh"

# Source shell
source "~/.zshrc"
