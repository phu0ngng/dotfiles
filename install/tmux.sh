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

#	# Install libevent if not present or version < 2.1.12
#	LIBEVENT_INC=$HOME/$InsDir/libevent/include
#	LIBEVENT_LIB=$HOME/$InsDir/libevent/lib
#	if pkg-config --exists libevent 2>/dev/null && \
#	   awk -v v="$(pkg-config --modversion libevent)" \
#	       'BEGIN{split(v,a,"."); exit !(a[1]>2||(a[1]==2&&a[2]>1)||(a[1]==2&&a[2]==1&&a[3]+0>=12))}'; then
#		LIBEVENT_INC=$(pkg-config --variable=includedir libevent)
#		LIBEVENT_LIB=$(pkg-config --variable=libdir libevent)
#	else
#		wget -nc https://github.com/libevent/libevent/releases/download/release-2.1.12-stable/libevent-2.1.12-stable.tar.gz
#		tar -xzf libevent-2.1.12-stable.tar.gz
#		cd libevent-2.1.12-stable/
#		./configure --prefix=$HOME/$InsDir/libevent --disable-shared --disable-openssl
#		make -j
#		make install
#		cd ..
#		rm -rf libevent-2.1.12-stable*
#	fi
#
#	# Install ncurses if not present or version < 6.6
#	NCURSES_INC=$HOME/$InsDir/ncurses/include
#	NCURSES_LIB=$HOME/$InsDir/ncurses/lib
#	if pkg-config --exists ncurses 2>/dev/null && \
#	   awk -v v="$(pkg-config --modversion ncurses)" \
#	       'BEGIN{split(v,a,"."); exit !(a[1]>6||(a[1]==6&&a[2]+0>=6))}'; then
#		NCURSES_INC=$(pkg-config --variable=includedir ncurses)
#		NCURSES_LIB=$(pkg-config --variable=libdir ncurses)
#	else
#		wget -nc https://ftp.gnu.org/pub/gnu/ncurses/ncurses-6.6.tar.gz
#		tar -xzf ncurses-6.6.tar.gz
#		cd ncurses-6.6/
#		./configure --prefix=$HOME/$InsDir/ncurses
#		make -j
#		make install
#		cd ..
#		rm -rf ncurses-6.6*
#	fi

wget -nc "https://github.com/tmux/tmux/releases/download/${TMUX_VERSION}/tmux-${TMUX_VERSION}.tar.gz"
tar -xzf "tmux-${TMUX_VERSION}.tar.gz"
cd "tmux-${TMUX_VERSION}/"
./configure --prefix=$HOME/$InsDir/tmux \
	CFLAGS="-I$LIBEVENT_INC -I$NCURSES_INC -I$NCURSES_INC/ncurses" \
	LDFLAGS="-L$LIBEVENT_LIB -L$NCURSES_LIB"
CPPFLAGS="-I$LIBEVENT_INC -I$NCURSES_INC -I$NCURSES_INC/ncurses" \
	LDFLAGS="-static -L$LIBEVENT_LIB -L$NCURSES_LIB" make -j
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
