#!/bin/bash

cp bash/.bashrc ~
cp tmux/.tmux.conf ~

# Install nvim
mkdir -p ~/local
cd ~/local
git clone https://github.com/neovim/neovim.git
make CMAKE_BUILD_TYPE=RelWithDebInfo CMAKE_INSTALL_PREFIX=~/local/nvim -j
make install

export PATH=~/local/nvim/bin:$PATH
export CPATH=~/local/nvim/include:$CPATH
export LD_LIBRARY_PATH=~/local/nvim/lib:$LD_LIBRARY_PATH
echo "# NVIM paths
export PATH=~/local/nvim/bin:$PATH
export CPATH=~/local/nvim/include:$CPATH
export LD_LIBRARY_PATH=~/local/nvim/lib:$LD_LIBRARY_PATH
" >> ~/.barhrc

# Install nvim plugin
sh -c 'curl -fLo "${XDG_DATA_HOME:-$HOME/.local/share}"/nvim/site/autoload/plug.vim --create-dirs \
       https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim'
pip3 install --user pynvim
mkdir -p ~/.config/nvim
cp vim/init.vim ~/.config/nvim/init.vim
nvim +'PlugInstall --sync' +qa
nvim +'UpdateRemotePlugins --sync' +qa

echo "Done\n"

