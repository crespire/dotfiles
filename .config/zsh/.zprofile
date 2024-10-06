if command -v brew; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi

export PGGSSENCMODE=disable

# For Loading the SSH key
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519
ssh-add ~/.ssh/id_ed25519.signing
