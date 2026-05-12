#!/bin/bash
# Top-level orchestrator. Runs every component installer in install/.
# Usage: ./install.sh <host>
# To install a single component: ./install/<component>.sh <host>

set -e

if [ -z "$1" ]; then
	echo "Error: No host specified. Usage: ./install.sh <host>"
	exit 1
fi
host="$1"

DotFilesDir=$(cd "$(dirname "$0")" && pwd)
export DotFilesDir

"$DotFilesDir/install/dotfiles.sh"    "$host"
"$DotFilesDir/install/cmake.sh"       "$host"
"$DotFilesDir/install/tmux.sh"        "$host"
"$DotFilesDir/install/python.sh"      "$host"
"$DotFilesDir/install/ninja.sh"       "$host"
"$DotFilesDir/install/nvim.sh"        "$host"

source ~/.bashrc || true

"$DotFilesDir/install/nvim-config.sh" "$host"
"$DotFilesDir/install/claude.sh"

echo "Done"
cd ~
