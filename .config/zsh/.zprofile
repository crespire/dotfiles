if command -v brew; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi

# Add libpq binaries to PATH if installed via Homebrew
if [ -d "/opt/homebrew/opt/libpq/bin" ]; then
  export PATH="/opt/homebrew/opt/libpq/bin:$PATH"
fi

export PGGSSENCMODE=disable
if [ -f "$HOME/.cargo/env" ]; then
  . "$HOME/.cargo/env"
fi

export PKG_CONFIG_PATH=/usr/local/lib/pkgconfig:/usr/local/opt/libxml2/lib/pkgconfig:/opt/X11/lib/pkgconfig:/usr/local/opt/libffi/lib/pkgconfig

export GOPATH=/Users/username/go
export PATH=$GOPATH/bin:$PATH
export EDITOR=nvim

# Added by OrbStack: command-line tools and integration
# This won't be added again if you remove it.
source ~/.orbstack/shell/init.zsh 2>/dev/null || :
