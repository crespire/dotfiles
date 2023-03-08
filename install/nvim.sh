# Add PPA for Unstable (nightly)
add-apt-repository -y ppa:neovim-ppa/unstable
apt -y update
apt-get -y install software-properties-common
apt -y install neovim
