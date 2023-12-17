#!/bin/sh

if [ ! -d ~/.asdf ]; then
	git clone https://github.com/asdf-vm/asdf.git ~/.asdf --branch v0.13.1
fi

source $HOME/.asdf/asdf.sh

# Install Ruby
asdf plugin add ruby https://github.com/asdf-vm/asdf-ruby.git
asdf install ruby latest
asdf global ruby latest

# Node
asdf plugin add nodejs https://github.com/asdf-vm/asdf-nodejs.git
asdf install nodejs latest:20
asdf global nodejs latest:20

# Yarn
asdf plugin add yarn https://github.com/twuni/asdf-yarn
# See https://github.com/twuni/asdf-yarn/issues/33 - latest .22 is missing artifacts
asdf install yarn 1.22.19
asdf global yarn 1.22.19

# Go
asdf plugin add golang https://github.com/kennyp/asdf-golang
asdf install golang latest
asdf global golang latest
