#!/bin/bash
# Install CMake (pre-built binary) into ~/$InsDir/cmake if not present.
set -e
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh" "$@"

if command -v cmake &> /dev/null; then
	echo "cmake already installed: $(command -v cmake)"
	exit 0
fi

cd ~/"$InsDir"
wget -nc https://github.com/Kitware/CMake/releases/download/v4.2.3/cmake-4.2.3-linux-x86_64.tar.gz
tar -xzf cmake-4.2.3-linux-x86_64.tar.gz
mv cmake-4.2.3-linux-x86_64 cmake
rm cmake-4.2.3-linux-x86_64.tar.gz

export PATH=~/$InsDir/cmake/bin:$PATH
echo "# Cmake paths
export PATH=~/$InsDir/cmake/bin:\$PATH
" >> ~/"$EnvFile"
