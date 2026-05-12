#!/bin/bash
# Link nvim config and set up the Python venv with packages nvim plugins expect.
set -e
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh" "$@"

rm -rf ~/.config/nvim
mkdir -p ~/.config
ln -s "$DotFilesDir/nvim" ~/.config/nvim

mkdir -p ~/.local/venv
python3 -m venv ~/.local/venv
source ~/.local/venv/bin/activate

pip3 install neovim flake8 black prettier ripgrep
pip3 install "python-lsp-server[all]" -U setuptools cpplint
