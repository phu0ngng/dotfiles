#!/bin/bash
# Build Python 3.13.8 into ~/$InsDir/python if python3 < 3.13 or missing.
set -e
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh" "$@"

PY3_VER=$(python3 --version 2>&1 | grep -oP '(?<=Python 3\.)\d+' || echo "0")
if command -v python3 &> /dev/null && [ "$PY3_VER" -ge 13 ]; then
	echo "python3 already installed: $(python3 --version)"
	exit 0
fi

cd ~/"$InsDir"
wget -nc https://www.python.org/ftp/python/3.13.8/Python-3.13.8.tar.xz
tar -xf Python-3.13.8.tar.xz
cd Python-3.13.8/
mkdir -p ../python
./configure --prefix=$(pwd)/../python --enable-optimizations --enable-shared
make -j 8
make altinstall -j 8
cd ..
rm -rf Python-3.13.8*

export PATH=~/$InsDir/python/bin:$PATH
export LD_LIBRARY_PATH=~/$InsDir/python/lib:$LD_LIBRARY_PATH
echo "# Python paths
export PATH=~/$InsDir/python/bin:\$PATH
export LD_LIBRARY_PATH=~/$InsDir/python/lib:\$LD_LIBRARY_PATH
" >> ~/"$EnvFile"
