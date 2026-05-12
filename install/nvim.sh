#!/bin/bash
# Install Neovim (pre-built binary) into ~/$InsDir/nvim if not present.
set -e
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh" "$@"

if command -v nvim &> /dev/null; then
	echo "nvim already installed: $(command -v nvim)"
	exit 0
fi

echo "Installing Nvim ..."
cd ~/"$InsDir"
wget -nc https://github.com/neovim/neovim/releases/latest/download/nvim-linux-x86_64.tar.gz
tar -xzf nvim-linux-x86_64.tar.gz
mv nvim-linux-x86_64 nvim
rm nvim-linux-x86_64.tar.gz

export PATH=~/$InsDir/nvim/bin:$PATH
export LD_LIBRARY_PATH=~/$InsDir/nvim/lib:$LD_LIBRARY_PATH
echo "# NVIM paths
export PATH=~/$InsDir/nvim/bin:\$PATH
export LD_LIBRARY_PATH=~/$InsDir/nvim/lib:\$LD_LIBRARY_PATH
" >> ~/"$EnvFile"
echo "... Done"
