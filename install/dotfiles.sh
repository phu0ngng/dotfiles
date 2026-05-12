#!/bin/bash
# Symlink shell, tmux, and Claude config from this repo into $HOME.
set -e
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh" "$@"

ln -sf "$DotFilesDir/bash/.bashrc" ~/.bashrc
ln -sf "$DotFilesDir/tmux/.tmux.conf" ~/.tmux.conf

mkdir -p ~/.claude
ln -sf "$DotFilesDir/claude/settings.json" ~/.claude/settings.json
ln -sf "$DotFilesDir/claude/CLAUDE.md" ~/.claude/CLAUDE.md
