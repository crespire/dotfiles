if command -v brew; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi

export PGGSSENCMODE=disable
. "$HOME/.cargo/env"
