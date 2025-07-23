if command -v brew; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi

export PGGSSENCMODE=disable
. "$HOME/.cargo/env"

export export PKG_CONFIG_PATH=/usr/local/lib/pkgconfig:/usr/local/opt/libxml2/lib/pkgconfig:/opt/X11/lib/pkgconfig:/usr/local/opt/libffi/lib/pkgconfig

export GOPATH=/Users/username/go
export PATH=$GOPATH/bin:$PATH

# Added by OrbStack: command-line tools and integration
# This won't be added again if you remove it.
source ~/.orbstack/shell/init.zsh 2>/dev/null || :
