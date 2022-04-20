#!/bin/bash

cp bash/.bashrc ~
cp vim/.vimrc ~
cp tmux/.tmux.conf ~

# Install vim plugin
## Vundle
mkdir -p ~/.vim/bundle/
git clone git@github.com:VundleVim/Vundle.vim.git ~/.vim/bundle/Vundle.vim
vim +PluginInstall +qall
## YouCompleteMe
#sudo apt install build-essential cmake vim-nox python3-dev -y
#sudo apt install mono-complete golang nodejs default-jdk npm -y
cd ~/.vim/bundle/
git clone https://github.com/ycm-core/YouCompleteMe.git
cd ~/.vim/bundle/YouCompleteMe
python3 install.py --all
