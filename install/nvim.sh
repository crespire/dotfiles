# Add PPA for Unstable (nightly)
sudo add-apt-repository -y ppa:neovim-ppa/unstable
sudo apt -y update
sudo apt-get -y install software-properties-common
sudo apt -y install neovim
git clone --depth 1 https://github.com/wbthomason/packer.nvim\
 ~/.local/share/nvim/site/pack/packer/start/packer.nvim

echo "Adding plugins via Packer..."
nvim --headless -c 'autocmd User PackerComplete quitall' -c 'PackerSync'
