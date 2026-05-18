#!/bin/bash
# Install Claude CLI into $WORKSPACE/.local/{share,bin}-$ARCH (per-arch so the
# x86 and aarch64 binaries can coexist on shared Lustre), and symlink
# $HOME/.claude{,.json} -> $WORKSPACE/.claude{,.json} so login-node and
# container share the same config/auth.
set -e
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh" "$@"

: "${WORKSPACE:?WORKSPACE must be set (per-cluster Lustre dir)}"

INSTALLER="${DotFilesDir}/claude/install_arch.sh"
[ -x "$INSTALLER" ] || { echo "Missing: $INSTALLER"; exit 1; }

# Install binaries for both archs into $WORKSPACE.
bash "$INSTALLER" --arch both

# Symlink ~/.claude{,.json} -> $WORKSPACE so the login shell sees the same
# config the container does.
mkdir -p "${WORKSPACE}/.claude"
[ -s "${WORKSPACE}/.claude.json" ] || echo '{}' > "${WORKSPACE}/.claude.json"

# Seed $WORKSPACE/.claude with the canonical CLAUDE.md and settings.json from
# this dotfiles repo (overwrites — these are the source of truth).
for f in CLAUDE.md settings.json; do
    cp -f "${DotFilesDir}/claude/${f}" "${WORKSPACE}/.claude/${f}"
done

for f in .claude .claude.json; do
    src="${WORKSPACE}/${f}"
    dst="$HOME/${f}"
    if [ -L "$dst" ]; then
        ln -snf "$src" "$dst"
    elif [ -e "$dst" ]; then
        echo "Skipping $dst: exists and is not a symlink (move it aside to re-link)."
    else
        ln -s "$src" "$dst"
    fi
done

echo "Claude installed to \$WORKSPACE; PATH for the matching arch is set in bash/.bashrc."
