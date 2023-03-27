#!/bin/bash

# Utilities
sudo apt-get -y update && sudo apt-get -y upgrade
sudo apt-get -y install software-properties-common
sudo apt-get -y install build-essential
sudo apt-get -y install libssl-dev
sudo apt-get -y install zlib1g zlib1g-dev
sudo apt-get -y install ripgrep

# Install Jetbrains Mono Nerdfonts
echo "Downloading JetBrains Mono..."
wget https://github.com/ryanoasis/nerd-fonts/releases/download/v2.3.3/JetBrainsMono.zip
unzip JetBrainsMono.zip -d ~/.fonts
fc-cache -fv
echo "Installed JetBrains Mono!"

# Go Lint
# sudo curl -sSfL https://raw.githubusercontent.com/golangci/golangci-lint/master/install.sh | sh -s -- -b $(go env GOPATH)/bin v1.52.2
