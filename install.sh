#!/usr/bin/bash

# Set failure mode
set -eEuo pipefail

# This sets the following:
# e = exit on a non-zero status code
# E = inherit traps on ERR, unsure tbh.
# u = treat unset variables as errors, so we exit setup if there is an issue
# o = run an option, in this case "pipefail" returns the last command to exit
#     with non-zero status, returns 0 if all commands in the pipeline are a
#     success.


printf "Let's install some stuff..."

# Install network fetch util
sudo apt -y install curl

export DOTFILES_DIR DOTFILES_CACHE DOTFILES_EXTRA_DIR
DOTFILES_DIR="$HOME/.dotfiles"
# DOTFILES_CACHE="$DOTFILES_DIR/.cache.sh"

. "$DOTFILES_DIR/git/options.sh"

# Set up Bitwarden env vars if not present
if [[ -z "${BW_CLIENTID}" ]]; then
  echo "Bitwarden client id: "
  read -n BW_CLIENTID
  export BW_CLIENTID="$BW_CLIENTID"
fi
if [[ -z "${BW_CLIENTSECRET}" ]]; then
  echo "Bitwarden client secret: "
  read -n BW_CLIENTSECRET
  export BW_CLIENTSECRET="$BW_CLIENTSECRET"
fi

# Make utilities available
# Once we have some utilities we can add them to ~/.dotfiles/bin as executable
# PATH="$DOTFILES_DIR/bin:$PATH"

# Set up links
ln -sfv "$DOTFILES_DIR/.config/bash/*" "$HOME"
ln -sfv "$DOTFILES_DIR/.config/.asdfrc" "$HOME"
ln -sfv "$DOTFILES_DIR/.config/nvim" "$HOME/.config"
ln -sfv "$DOTFILES_DIR/lang-defaults/*" "$HOME"

source "$HOME/.bashrc"

# Install some packages
. "$DOTFILES_DIR/install/utils.sh"
. "$DOTFILES_DIR/install/nvim.sh"
. "$DOTFILES_DIR/install/asdf_install.sh"

# Sets vi movement for terminal
set -o vi
