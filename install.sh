#!/bin/bash

DotFilesDir=$(pwd)

cp $DotFilesDir/bash/.bashrc ~
cp $DotFilesDir/tmux/.tmux.conf ~

host=$(hostname  | cut -d - -f 1 | cut -d . -f 1)
InsDir="local/$host"
mkdir -p $InsDir

EnvFile=".env_$host"
touch ~/$EnvFile

# Install cmake
if ! command -v cmake &> /dev/null
then
	mkdir -p ~/$InsDir
	cd ~/$InsDir
	wget https://github.com/Kitware/CMake/releases/download/v3.26.1/cmake-3.26.1.tar.gz
	tar -xvf cmake-3.26.1.tar.gz
	cd cmake-3.26.1/
	./bootstrap
	./configure --prefix=$HOME/$InsDir/cmake
	make -j
	make install
	rm cmake-3.26.1.*

	export PATH=~/$InsDir/cmake/bin:$PATH
	echo "# Cmake paths
	export PATH=~/$InsDir/cmake/bin:\$PATH
	" >> ~/$EnvFile
fi

# Install  tmux
if ! command -v tmux &> /dev/null \
    || test $(tmux -V | grep -oE '[0-9]+\.[0-9]+' | head -1 | awk -F. '$1 < 3 || $1 == 3 && $2 < 4');
then
	mkdir -p ~/$InsDir
	cd ~/$InsDir
	# installing libevent
	wget  https://github.com/libevent/libevent/releases/download/release-2.1.12-stable/libevent-2.1.12-stable.tar.gz
	tar -xvf libevent-2.1.12-stable.tar.gz
	cd libevent-2.1.12-stable/
	./configure --prefix=$HOME/$InsDir/libevent --disable-shared --disable-openssl
	make -j
	make install
	cd ..
	rm -rf libevent-2.1.12-stable*
	# install ncurses
	wget https://ftp.gnu.org/pub/gnu/ncurses/ncurses-6.4.tar.gz
	tar -xvf ncurses-6.4.tar.gz
	cd ncurses-6.4/
	./configure --prefix=$HOME/$InsDir/ncurses
	make -j
	make install
	cd ..
	rm -rf ncurses-6.4*
	# install tmux
	wget https://github.com/tmux/tmux/releases/download/3.5/tmux-3.5.tar.gz
	tar -xvf tmux-3.5.tar.gz
	cd tmux-3.5/
	./configure --prefix=$HOME/$InsDir/tmux  CFLAGS="-I$HOME/$InsDir/libevent/include -I$HOME/$InsDir/ncurses/include -I$HOME/$InsDir/ncurses/include/ncurses" LDFLAGS="-L$HOME/$InsDir/libevent/lib -L$HOME/$InsDir/ncurses/lib"
	CPPFLAGS="-I$HOME/$InsDir/libevent/include -I$HOME/$InsDir/ncurses/include -I$HOME/$InsDir/ncurses/include/ncurses" LDFLAGS="-static -L$HOME/$InsDir/libevent/lib -L$HOME/$InsDir/ncurses/lib" make -j 2
	make install
	cd ..
	rm -rf tmux-3.4 tmux-3.4.tar.gz
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
if ! command -v python3 &> /dev/null \
       	|| test $(python3 --version 2>&1 | cut -d . -f 2) -lt 10 ;
then
	mkdir -p ~/$InsDir
	cd ~/$InsDir
	wget https://www.python.org/ftp/python/3.12.3/Python-3.12.3.tar.xz
	tar -xvf Python-3.12.3.tar.xz
	cd Python-3.12.3/
	mkdir -p ../python
	./configure --prefix=$(pwd)/../python --enable-optimizations --enable-shared
	make -j
	make install
	cd ..
	export PATH=~/$InsDir/python/bin:$PATH
	export LD_LIBRARY_PATH=~/$InsDir/python/lib:$LD_LIBRARY_PATH
	echo "# Python paths
	export PATH=~/$InsDir/python/bin:\$PATH
	#export CPATH=~/$InsDir/python/include:\$CPATH
	export LD_LIBRARY_PATH=~/$InsDir/python/lib:\$LD_LIBRARY_PATH
	" >> ~/$EnvFile
	rm -rf Python-3.12.3*
    # Install pip3
	wget --no-check-certificate https://bootstrap.pypa.io/get-pip.py && $(which python3.12) get-pip.py --user
	export PATH=~/.local/bin:$PATH
	export LD_LIBRARY_PATH=~/.local/lib:$LD_LIBRARY_PATH
	echo "# Pip packages
	export PATH=~/.local/bin:\$PATH
	export LD_LIBRARY_PATH=~/.local/lib:\$LD_LIBRARY_PATH
	 " >> ~/$EnvFile
   rm get-pip.py
fi

# Install pip3
if ! command -v pip3 &> /dev/null
then
	wget --no-check-certificate https://bootstrap.pypa.io/get-pip.py && $(which python3) get-pip.py --user
	export PATH=~/.$InsDir/bin:$PATH
	export LD_LIBRARY_PATH=~/.$InsDir/lib:$LD_LIBRARY_PATH
	echo "# Pip3 paths
	export PATH=~/.$InsDir/bin:\$PATH
	export LD_LIBRARY_PATH=~/.$InsDir/lib:\$LD_LIBRARY_PATH
	" >> ~/$EnvFile
  rm get-pip.py
fi

# Install Ninja
if ! command -v ninja &> /dev/null
then
	echo "Ninja could not be found"
	echo "Installing Ninja ..."
	mkdir -p ~/$InsDir
	cd ~/$InsDir
	git clone https://github.com/ninja-build/ninja.git
	cd ninja/
	git checkout release
	mkdir -p build
	cd build/
	cmake ..
	make -j
	export PATH=~/$InsDir/ninja/build:$PATH
	echo "# Ninja path
	export PATH=~/$InsDir/ninja/build:\$PATH
	" >> ~/$EnvFile
fi

# Install LLVM Clang
#if ! command -v clang &> /dev/null
#then
#	echo "Clang could not be found"
#	echo "Installing Clang ..."
#	cd ~/$InsDir
#	git clone https://github.com/llvm/llvm-project.git
#	cd llvm-project
#	git checkout release
#	cmake -S llvm -B build -G "Ninja" -DCMAKE_BUILD_TYPE=MinSizeRel -DLLVM_ENABLE_PROJECTS="clang"
#	cd  build &&  ninja
#	export PATH=~/$InsDir/llvm-project/build/bin:$PATH
#	export LD_LIBRARY_PATH=~/$InsDir/llvm-project/build/lib:$LD_LIBRARY_PATH
#	echo "# Clang-Format
#	export PATH=~/$InsDir/llvm-project/build/bin:\$PATH
#	export LD_LIBRARY_PATH=~/$InsDir/llvm-project/build/lib:\$LD_LIBRARY_PATH
#	" >> ~/$EnvFile
#fi


# Install nvim
if ! command -v nvim &> /dev/null
then
	echo "Nvim could not be found"
	echo "Installing Nvim ..."
	mkdir -p ~/$InsDir
	cd ~/$InsDir
#	git clone https://github.com/neovim/neovim.git
#	cd neovim
#	git checkout release-0.8
#	make CMAKE_BUILD_TYPE=RelWithDebInfo CMAKE_INSTALL_PREFIX=~/$InsDir/nvim -j
#	make install

	wget https://github.com/neovim/neovim/releases/latest/download/nvim-linux-x86_64.tar.gz
	tar -xvf nvim-linux-x86_64.tar.gz
	mv nvim-linux-x86_64 nvim

	export PATH=~/$InsDir/nvim/bin:$PATH
	export LD_LIBRARY_PATH=~/$InsDir/nvim/lib:$LD_LIBRARY_PATH
	echo "# NVIM paths
	export PATH=~/$InsDir/nvim/bin:\$PATH
	#export CPATH=~/$InsDir/nvim/include:\$CPATH
	export LD_LIBRARY_PATH=~/$InsDir/nvim/lib:\$LD_LIBRARY_PATH
	" >> ~/$EnvFile

	echo "... Done"
fi

# Install nvim plugin
mkdir -p ~/.config/nvim
cp -r $DotFilesDir/nvim/* ~/.config/nvim/
echo "vim.g.python3_host_prog='$(which python3)'" >> ~/.config/nvim/lua/options.lua
#
pip3 install neovim flake8 black prettier
pip3 install "python-lsp-server[all]" -U setuptools cpplint
echo "Done\n"
cd ~

