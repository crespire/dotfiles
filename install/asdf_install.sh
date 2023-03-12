#!/bin/bash

if [ ! -d ~/.asdf ]; then
  git clone https://github.com/asdf-vm/asdf.git ~/.asdf --branch v0.11.2
fi

. $HOME/.asdf/asdf.sh

# Install Ruby
asdf plugin add ruby https://github.com/asdf-vm/asdf-ruby.git
asdf install ruby 3.1.3
asdf global ruby 3.1.3

# Node
asdf plugin add nodejs https://github.com/asdf-vm/asdf-nodejs.git
asdf install nodejs 18.15.0
asdf global nodejs 18.15.0

# Yarn
asdf plugin add yarn https://github.com/twuni/asdf-yarn
asdf install yarn latest
asdf global yarn latest
