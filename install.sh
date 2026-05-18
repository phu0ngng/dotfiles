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

# Pick up PATH from any prior partial install so component scripts can skip work.
[ -f ~/".env_$host" ] && source ~/".env_$host"

"$DotFilesDir/install/dotfiles.sh"    "$host"
"$DotFilesDir/install/cmake.sh"       "$host"
"$DotFilesDir/install/tmux.sh"        "$host"
"$DotFilesDir/install/python.sh"      "$host"
"$DotFilesDir/install/ninja.sh"       "$host"
"$DotFilesDir/install/nvim.sh"        "$host"
"$DotFilesDir/install/claude.sh"      "$host"

# Pick up PATH updates from completed installers before nvim-config needs python3.
source ~/".env_$host"

"$DotFilesDir/install/nvim-config.sh" "$host"

echo "Done"
cd ~
