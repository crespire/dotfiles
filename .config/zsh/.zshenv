# zsh reads this file for every shell, including non-login, non-interactive
# shells such as the ones Claude Code spawns. Keep it to environment only:
# nothing here may print output, because output breaks scp, rsync and other
# tools that talk over a non-interactive shell.

# .zprofile sources this file a second time, so the unique flag stops
# duplicate entries and moves each prepended entry back to the front.
typeset -U path PATH fpath FPATH

# Homebrew
if [ -x /opt/homebrew/bin/brew ]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi

if [ -d /opt/homebrew/opt/libpq/bin ]; then
  export PATH="/opt/homebrew/opt/libpq/bin:$PATH"
fi

export PKG_CONFIG_PATH=/usr/local/lib/pkgconfig:/usr/local/opt/libxml2/lib/pkgconfig:/opt/X11/lib/pkgconfig:/usr/local/opt/libffi/lib/pkgconfig

# Rust
if [ -f "$HOME/.cargo/env" ]; then
  . "$HOME/.cargo/env"
fi

# Go. In interactive shells, the asdf golang precmd hook in .zshrc replaces
# GOPATH with the path of the active asdf Go version.
export GOPATH="$HOME/go"
export PATH="$GOPATH/bin:$PATH"
export ASDF_GOLANG_MOD_VERSION_ENABLED=true

# Google Cloud SDK
if [ -f "$HOME/google-cloud-sdk/path.zsh.inc" ]; then
  . "$HOME/google-cloud-sdk/path.zsh.inc"
fi

# Some apps install to this location regardless of OS
export PATH="$HOME/.local/bin:$PATH"

# asdf shims go first, so asdf-managed runtimes win over Homebrew ones
if [ -d "${ASDF_DATA_DIR:-$HOME/.asdf}/shims" ]; then
  export PATH="${ASDF_DATA_DIR:-$HOME/.asdf}/shims:$PATH"
fi

# Appended tools: these must not shadow anything above
if [ -d /opt/nvim-linux-x86_64/bin ]; then
  export PATH="$PATH:/opt/nvim-linux-x86_64/bin"
fi

if [ -d "$HOME/.fzf/bin" ]; then
  export PATH="$PATH:$HOME/.fzf/bin"
fi

# OrbStack: command-line tools and integration
source ~/.orbstack/shell/init.zsh 2>/dev/null || :

export EDITOR=nvim
export PGGSSENCMODE=disable
export TICKETS_DIR="$HOME/.tickets"
