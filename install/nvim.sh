# Add PPA for Unstable (nightly)
sudo add-apt-repository -y ppa:neovim-ppa/unstable
sudo apt -y update
sudo apt-get -y install software-properties-common
sudo apt -y install neovim

nvim --headless -c 'PackerSync'
