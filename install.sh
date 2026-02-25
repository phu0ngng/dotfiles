#!/bin/bash

DotFilesDir=$(pwd)

cp $DotFilesDir/bash/.bashrc ~
cp $DotFilesDir/tmux/.tmux.conf ~

# Host must be passed as argument: ./install.sh <host>
if [ -z "$1" ]; then
	echo "Error: No host specified. Usage: ./install.sh <host>"
	exit 1
fi
host="$1"

echo "$host" > ~/.dotfiles_host
InsDir="local/$host"
mkdir -p $InsDir

EnvFile=".env_$host"
touch ~/$EnvFile

# Install cmake (pre-built binary)
if ! command -v cmake &> /dev/null
then
	mkdir -p ~/$InsDir
	cd ~/$InsDir
	wget -nc https://github.com/Kitware/CMake/releases/download/v4.2.3/cmake-4.2.3-linux-x86_64.tar.gz
	tar -xzf cmake-4.2.3-linux-x86_64.tar.gz
	mv cmake-4.2.3-linux-x86_64 cmake
	rm cmake-4.2.3-linux-x86_64.tar.gz

	export PATH=~/$InsDir/cmake/bin:$PATH
	echo "# Cmake paths
	export PATH=~/$InsDir/cmake/bin:\$PATH
	" >> ~/$EnvFile
fi

# Install tmux
if ! command -v tmux &> /dev/null \
    || test $(tmux -V | grep -oE '[0-9]+\.[0-9]+' | head -1 | awk -F. '$1 < 3 || $1 == 3 && $2 < 6');
then
	mkdir -p ~/$InsDir
	cd ~/$InsDir

	# Install libevent if not present or version < 2.1.12
	LIBEVENT_INC=$HOME/$InsDir/libevent/include
	LIBEVENT_LIB=$HOME/$InsDir/libevent/lib
	if pkg-config --exists libevent 2>/dev/null && \
	   awk -v v="$(pkg-config --modversion libevent)" \
	       'BEGIN{split(v,a,"."); exit !(a[1]>2||(a[1]==2&&a[2]>1)||(a[1]==2&&a[2]==1&&a[3]+0>=12))}'; then
		LIBEVENT_INC=$(pkg-config --variable=includedir libevent)
		LIBEVENT_LIB=$(pkg-config --variable=libdir libevent)
	else
		wget -nc https://github.com/libevent/libevent/releases/download/release-2.1.12-stable/libevent-2.1.12-stable.tar.gz
		tar -xzf libevent-2.1.12-stable.tar.gz
		cd libevent-2.1.12-stable/
		./configure --prefix=$HOME/$InsDir/libevent --disable-shared --disable-openssl
		make -j
		make install
		cd ..
		rm -rf libevent-2.1.12-stable*
	fi

	# Install ncurses if not present or version < 6.6
	NCURSES_INC=$HOME/$InsDir/ncurses/include
	NCURSES_LIB=$HOME/$InsDir/ncurses/lib
	if pkg-config --exists ncurses 2>/dev/null && \
	   awk -v v="$(pkg-config --modversion ncurses)" \
	       'BEGIN{split(v,a,"."); exit !(a[1]>6||(a[1]==6&&a[2]+0>=6))}'; then
		NCURSES_INC=$(pkg-config --variable=includedir ncurses)
		NCURSES_LIB=$(pkg-config --variable=libdir ncurses)
	else
		wget -nc https://ftp.gnu.org/pub/gnu/ncurses/ncurses-6.6.tar.gz
		tar -xzf ncurses-6.6.tar.gz
		cd ncurses-6.6/
		./configure --prefix=$HOME/$InsDir/ncurses
		make -j
		make install
		cd ..
		rm -rf ncurses-6.6*
	fi

	# install tmux
	wget -nc https://github.com/tmux/tmux/releases/download/3.6a/tmux-3.6a.tar.gz
	tar -xzf tmux-3.6a.tar.gz
	cd tmux-3.6a/
	./configure --prefix=$HOME/$InsDir/tmux \
		CFLAGS="-I$LIBEVENT_INC -I$NCURSES_INC -I$NCURSES_INC/ncurses" \
		LDFLAGS="-L$LIBEVENT_LIB -L$NCURSES_LIB"
	CPPFLAGS="-I$LIBEVENT_INC -I$NCURSES_INC -I$NCURSES_INC/ncurses" \
		LDFLAGS="-static -L$LIBEVENT_LIB -L$NCURSES_LIB" make -j
	make install
	cd ..
	rm -rf tmux-3.6a*
	export PATH=~/$InsDir/tmux/bin:$PATH
	export CPATH=~/$InsDir/tmux/include:$CPATH
	export LD_LIBRARY_PATH=~/$InsDir/tmux/lib:$LD_LIBRARY_PATH
	echo "# Tmux paths
	export PATH=~/$InsDir/tmux/bin:\$PATH
	export CPATH=~/$InsDir/tmux/include:\$CPATH
	export LD_LIBRARY_PATH=~/$InsDir/tmux/lib:\$LD_LIBRARY_PATH
	" >> ~/$EnvFile
fi

# Install python3
PY3_VER=$(python3 --version 2>&1 | grep -oP '(?<=Python 3\.)\d+' || echo "0")
if ! command -v python3 &> /dev/null || test "$PY3_VER" -lt 13 ;
then
	mkdir -p ~/$InsDir
	cd ~/$InsDir
	wget -nc https://www.python.org/ftp/python/3.13.8/Python-3.13.8.tar.xz
	tar -xf Python-3.13.8.tar.xz
	cd Python-3.13.8/
	mkdir -p ../python
	./configure --prefix=$(pwd)/../python --enable-optimizations --enable-shared
	make -j
	make install
	cd ..
	rm -rf Python-3.13.8*
	export PATH=~/$InsDir/python/bin:$PATH
	export LD_LIBRARY_PATH=~/$InsDir/python/lib:$LD_LIBRARY_PATH
	echo "# Python paths
	export PATH=~/$InsDir/python/bin:\$PATH
	export LD_LIBRARY_PATH=~/$InsDir/python/lib:\$LD_LIBRARY_PATH
	" >> ~/$EnvFile
fi

# Install Ninja (pre-built binary)
if ! command -v ninja &> /dev/null
then
	echo "Ninja could not be found"
	echo "Installing Ninja ..."
	mkdir -p ~/$InsDir/ninja/bin
	cd ~/$InsDir/ninja/bin
	wget -nc https://github.com/ninja-build/ninja/releases/download/v1.13.2/ninja-linux.zip
	unzip ninja-linux.zip
	rm ninja-linux.zip
	export PATH=~/$InsDir/ninja/bin:$PATH
	echo "# Ninja path
	export PATH=~/$InsDir/ninja/bin:\$PATH
	" >> ~/$EnvFile
fi

# Install nvim
if ! command -v nvim &> /dev/null
then
	echo "Nvim could not be found"
	echo "Installing Nvim ..."
	mkdir -p ~/$InsDir
	cd ~/$InsDir
	wget -nc https://github.com/neovim/neovim/releases/latest/download/nvim-linux-x86_64.tar.gz
	tar -xzf nvim-linux-x86_64.tar.gz
	mv nvim-linux-x86_64 nvim
	rm nvim-linux-x86_64.tar.gz

	export PATH=~/$InsDir/nvim/bin:$PATH
	export LD_LIBRARY_PATH=~/$InsDir/nvim/lib:$LD_LIBRARY_PATH
	echo "# NVIM paths
	export PATH=~/$InsDir/nvim/bin:\$PATH
	export LD_LIBRARY_PATH=~/$InsDir/nvim/lib:\$LD_LIBRARY_PATH
	" >> ~/$EnvFile
	echo "... Done"
fi

source ~/.bashrc

# Install nvim config
mkdir -p ~/.config/nvim
cp -r $DotFilesDir/nvim/* ~/.config/nvim/

# Set up nvim python venv
mkdir -p ~/.local/venv
python3 -m venv ~/.local/venv/nvim
source ~/.local/venv/nvim/bin/activate

# Other packages for nvim
pip3 install neovim flake8 black prettier ripgrep
pip3 install "python-lsp-server[all]" -U setuptools cpplint

echo "Done"
cd ~
