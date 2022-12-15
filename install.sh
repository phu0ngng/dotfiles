#!/bin/bash

DDIR=$(pwd)

cp $DDIR/bash/.bashrc ~
cp $DDIR/tmux/.tmux.conf ~

# Install python3
if ! command -v python3 &> /dev/null
then
	mkdir -p ~/local
	cd ~/local
	wget https://www.python.org/ftp/python/3.11.1/Python-3.11.1.tar.xz
	tar -xvf Python-3.11.1.tar.xz
	cd Python-3.11.1/
	./configure --prefix=$(pwd)/../python --enable-optimizations
	make -j
	make install
  cd ..
	export PATH=~/local/python/bin:$PATH
	export CPATH=~/local/python/include:$CPATH
	export LD_LIBRARY_PATH=~/local/python/lib:$LD_LIBRARY_PATH
	echo "# Python paths
	export PATH=~/local/python/bin:$PATH
	export CPATH=~/local/python/include:$CPATH
	export LD_LIBRARY_PATH=~/local/python/lib:$LD_LIBRARY_PATH
	" >> ~/.bashrc
  rm -rf Python-3.11.1*
fi

# Install pip3
if ! command -v pip3 &> /dev/null
then
	wget --no-check-certificate https://bootstrap.pypa.io/get-pip.py && $(which python3) get-pip.py --user
	export PATH=~/.local/bin:$PATH
	export LD_LIBRARY_PATH=~/.local/lib:$LD_LIBRARY_PATH
	echo "# Pip3 paths
	export PATH=~/.local/bin:$PATH
	export LD_LIBRARY_PATH=~/.local/lib:$LD_LIBRARY_PATH
	" >> ~/.bashrc
  rm get-pip.py
fi

# Install nvim
if ! command -v nvim &> /dev/null
then
	echo "Nvim could not be found"
	echo "Installing Nvim ..."
	mkdir -p ~/local
	cd ~/local
	git clone https://github.com/neovim/neovim.git
	cd neovim
	make CMAKE_BUILD_TYPE=RelWithDebInfo CMAKE_INSTALL_PREFIX=~/local/nvim -j
	make install

	export PATH=~/local/nvim/bin:$PATH
	export CPATH=~/local/nvim/include:$CPATH
	export LD_LIBRARY_PATH=~/local/nvim/lib:$LD_LIBRARY_PATH
	echo "# NVIM paths
	export PATH=~/local/nvim/bin:$PATH
	export CPATH=~/local/nvim/include:$CPATH
	export LD_LIBRARY_PATH=~/local/nvim/lib:$LD_LIBRARY_PATH
	" >> ~/.bashrc

	cd ~/local
	rm -rf neovim/
	echo "... Done"
fi

# Install nvim plugin
sh -c 'curl -fLo "${XDG_DATA_HOME:-$HOME/.local/share}"/nvim/site/autoload/plug.vim --create-dirs \
       https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim'
$(which pip3) install --user pynvim
mkdir -p ~/.config/nvim
cp $DDIR/vim/init.vim ~/.config/nvim/init.vim
nvim +'PlugInstall --sync' +qa
nvim +'UpdateRemotePlugins --sync' +qa

echo "Done\n"
cd ~

# Alias nvim with vim
echo "# nvim
if [ -x "$(which nvim)" ]; then
  alias vim="$(which nvim)"
fi
" >> ~/.bashrc
