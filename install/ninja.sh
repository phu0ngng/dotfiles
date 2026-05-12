#!/bin/bash
# Install Ninja (pre-built binary) into ~/$InsDir/ninja/bin if not present.
set -e
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh" "$@"

if command -v ninja &> /dev/null; then
	echo "ninja already installed: $(command -v ninja)"
	exit 0
fi

echo "Installing Ninja ..."
mkdir -p ~/$InsDir/ninja/bin
cd ~/$InsDir/ninja/bin
wget -nc https://github.com/ninja-build/ninja/releases/download/v1.13.2/ninja-linux.zip
unzip ninja-linux.zip
rm ninja-linux.zip

export PATH=~/$InsDir/ninja/bin:$PATH
echo "# Ninja path
export PATH=~/$InsDir/ninja/bin:\$PATH
" >> ~/"$EnvFile"
