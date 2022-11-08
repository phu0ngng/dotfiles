#!/bin/bash

cp bash/.bashrc ~
cp tmux/.tmux.conf ~

# Install nvim plugin
sh -c 'curl -fLo "${XDG_DATA_HOME:-$HOME/.local/share}"/nvim/site/autoload/plug.vim --create-dirs \
       https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim'
pip3 install --user pynvim
mkdir -p ~/.config/nvim
cp vim/init.vim ~/.config/nvim/init.vim
nvim +'PlugInstall --sync' +qa
nvim +'UpdateRemotePlugins --sync' +qa
