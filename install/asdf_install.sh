#!/bin/sh

if [ ! -d ~/.asdf ]; then
	git clone https://github.com/asdf-vm/asdf.git ~/.asdf --branch v0.11.2
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
asdf install yarn latest
asdf global yarn latest

# Go
asdf plugin add golang https://github.com/kennyp/asdf-golang
asdf install golang latest
asdf global golang latest
