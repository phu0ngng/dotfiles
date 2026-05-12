#!/bin/bash
# Shared setup for install scripts. Source this from each component script.
# Provides: DotFilesDir, host, InsDir, EnvFile.
# Host resolution order: $HOST_ARG > $1 > ~/.dotfiles_host.

set -e

DotFilesDir="${DotFilesDir:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

host="${HOST_ARG:-${1:-}}"
if [ -z "$host" ] && [ -f ~/.dotfiles_host ]; then
	host=$(cat ~/.dotfiles_host)
fi
if [ -z "$host" ]; then
	echo "Error: No host specified. Pass as first arg or set HOST_ARG, or run install.sh <host> first." >&2
	exit 1
fi

echo "$host" > ~/.dotfiles_host
InsDir="local/$host"
mkdir -p ~/"$InsDir"

EnvFile=".env_$host"
touch ~/"$EnvFile"

export DotFilesDir host InsDir EnvFile
