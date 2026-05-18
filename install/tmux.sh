#!/bin/bash
# Build and install tmux into ~/$InsDir/tmux from upstream sources.
# Skip if a tmux at >= TMUX_VERSION_MIN is already on PATH.
set -e
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh" "$@"

# Bump this when a newer stable tmux is released; see
# https://github.com/tmux/tmux/releases/latest
TMUX_VERSION="3.6a"
TMUX_VERSION_MIN_MAJOR=3
TMUX_VERSION_MIN_MINOR=6

if command -v tmux &> /dev/null \
    && ! test $(tmux -V | grep -oE '[0-9]+\.[0-9]+' | head -1 \
        | awk -F. -v M=$TMUX_VERSION_MIN_MAJOR -v m=$TMUX_VERSION_MIN_MINOR \
            '$1 < M || ($1 == M && $2 < m)'); then
	echo "tmux already installed: $(tmux -V)"
	exit 0
fi

cd ~/"$InsDir"

# Build libevent locally if no system headers are available. We can't rely on
# pkg-config (cluster nodes have libevent the .so but not the headers/.pc file).
if [ -f /usr/include/event2/event.h ] || [ -f /usr/include/event.h ]; then
	LIBEVENT_CFG_FLAGS=""
else
	rm -rf libevent-2.1.12-stable
	wget -nc https://github.com/libevent/libevent/releases/download/release-2.1.12-stable/libevent-2.1.12-stable.tar.gz
	tar -xzf libevent-2.1.12-stable.tar.gz
	cd libevent-2.1.12-stable/
	./configure --prefix=$HOME/$InsDir/libevent --disable-shared --disable-openssl
	make -j
	make install
	cd ..
	rm -rf libevent-2.1.12-stable*
	LIBEVENT_CFG_FLAGS="CFLAGS=-I$HOME/$InsDir/libevent/include LDFLAGS=-L$HOME/$InsDir/libevent/lib"
fi

# Clean up any partial extraction from a previous failed run.
rm -rf "tmux-${TMUX_VERSION}"

wget -nc "https://github.com/tmux/tmux/releases/download/${TMUX_VERSION}/tmux-${TMUX_VERSION}.tar.gz"
tar -xzf "tmux-${TMUX_VERSION}.tar.gz"
cd "tmux-${TMUX_VERSION}/"
./configure --prefix=$HOME/$InsDir/tmux $LIBEVENT_CFG_FLAGS
make -j
make install
cd ..
rm -rf "tmux-${TMUX_VERSION}"*

export PATH=~/$InsDir/tmux/bin:$PATH
export CPATH=~/$InsDir/tmux/include:$CPATH
export LD_LIBRARY_PATH=~/$InsDir/tmux/lib:$LD_LIBRARY_PATH
echo "# Tmux paths
export PATH=~/$InsDir/tmux/bin:\$PATH
export CPATH=~/$InsDir/tmux/include:\$CPATH
export LD_LIBRARY_PATH=~/$InsDir/tmux/lib:\$LD_LIBRARY_PATH
" >> ~/"$EnvFile"
