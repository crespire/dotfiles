#!/bin/sh

# =============================================================================
# asdf Installation and Language Runtimes
# =============================================================================

# Clone asdf if not present
if [ ! -d ~/.asdf ]; then
	echo "Installing asdf..."
	git clone https://github.com/asdf-vm/asdf.git ~/.asdf
else
	echo "asdf already installed, updating..."
	cd ~/.asdf && git pull && cd -
fi

# Use . instead of source for POSIX compatibility
. "$HOME/.asdf/asdf.sh"

# Helper to add plugin idempotently
add_plugin() {
	local name="$1"
	local url="$2"
	if asdf plugin list | grep -q "^${name}$"; then
		echo "Plugin $name already installed"
	else
		echo "Adding plugin $name..."
		asdf plugin add "$name" "$url"
	fi
}

# =============================================================================
# Ruby
# =============================================================================
echo "Setting up Ruby..."
add_plugin ruby https://github.com/asdf-vm/asdf-ruby.git
asdf install ruby latest
asdf global ruby latest

# =============================================================================
# Node.js
# =============================================================================
echo "Setting up Node.js..."
add_plugin nodejs https://github.com/asdf-vm/asdf-nodejs.git
asdf install nodejs latest:20
asdf global nodejs latest:20

# =============================================================================
# Yarn
# =============================================================================
echo "Setting up Yarn..."
add_plugin yarn https://github.com/twuni/asdf-yarn
asdf install yarn 1.22.22
asdf global yarn 1.22.22

# =============================================================================
# Go
# =============================================================================
echo "Setting up Go..."
add_plugin golang https://github.com/kennyp/asdf-golang
asdf install golang latest
asdf global golang latest

echo "All language runtimes installed!"
