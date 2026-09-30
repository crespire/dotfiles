# Environment variables live in .zshenv, which zsh reads for every shell.
#
# In a login shell, /etc/zprofile runs macOS path_helper after .zshenv.
# path_helper moves the system directories (/usr/bin and others) ahead of the
# entries that .zshenv added, so the system ruby or git would win over the
# asdf and Homebrew ones. Source .zshenv again to put its entries back in front.
source "${ZDOTDIR:-$HOME}/.zshenv"
