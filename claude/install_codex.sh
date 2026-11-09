#!/bin/bash
# Install codex (OpenAI Codex CLI) into $WORKSPACE/.local/bin-<arch>/codex.
# Same pattern as install_arch.sh/install_glab.sh so it can run on a login
# node without a container. codex self-manages its own release under
# ~/.codex/packages/standalone/current, but that only tracks one arch at a
# time (whichever last ran the CLI natively). This installs the npm
# platform package directly into its own release dir per arch, so an arch
# codex's own updater never touched still gets a working binary.
#
# Usage:
#   WORKSPACE=/path/to/lustre/dir \
#     ./install_codex.sh [--arch x86_64|aarch64|both] [--version latest|X.Y.Z]
set -euo pipefail

: "${WORKSPACE:?WORKSPACE must be set (the per-cluster Lustre dir)}"
ARCH_ARG="both"
VERSION="latest"

while [ $# -gt 0 ]; do
    case "$1" in
        --arch)    ARCH_ARG="$2"; shift 2 ;;
        --version) VERSION="$2"; shift 2 ;;
        -h|--help) sed -n '2,13p' "$0"; exit 0 ;;
        *) echo "Unknown arg: $1"; exit 1 ;;
    esac
done

REGISTRY="https://registry.npmjs.org/@openai/codex"

resolve_version() {
    local v="$1"
    if [ "$v" = "latest" ]; then
        curl -fsSL "${REGISTRY}/latest" | grep -o '"version":"[^"]*"' | head -n1 | cut -d'"' -f4
    else
        echo "$v"
    fi
}

install_one() {
    local arch_name="$1" npm_plat target
    case "$arch_name" in
        x86_64)  npm_plat="linux-x64"; target="x86_64-unknown-linux-musl" ;;
        aarch64) npm_plat="linux-arm64"; target="aarch64-unknown-linux-musl" ;;
        *) echo "Bad arch: $arch_name"; return 1 ;;
    esac

    local bin_dir="${WORKSPACE}/.local/bin-${arch_name}"
    mkdir -p "$bin_dir"

    local version; version=$(resolve_version "$VERSION")
    [ -n "$version" ] || { echo "Failed to resolve codex version"; return 1; }

    local release_dir="${WORKSPACE}/.codex/packages/standalone/releases/${version}-${target}"
    if [ -x "${release_dir}/bin/codex" ]; then
        echo "[${arch_name}] codex ${version} already present."
    else
        local tmp; tmp=$(mktemp -d)
        trap 'rm -rf "$tmp"' RETURN
        local url="${REGISTRY}/-/codex-${version}-${npm_plat}.tgz"
        echo "[${arch_name}] downloading codex ${version} (${npm_plat})..."
        curl -fsSL -o "$tmp/codex.tgz" "$url" || { echo "  fetch failed: $url"; return 1; }
        tar xzf "$tmp/codex.tgz" -C "$tmp"
        local vendor_dir="$tmp/package/vendor/${target}"
        [ -d "$vendor_dir" ] || { echo "  vendor dir not found for ${target}"; return 1; }
        mkdir -p "$release_dir"
        cp -a "$vendor_dir/." "$release_dir/"
        chmod +x "$release_dir/bin/codex"
    fi

    # Symlink straight to this arch's release, not "current" -- that pointer
    # belongs to codex's own self-updater on the host's native arch.
    ln -sf "${release_dir}/bin/codex" "${bin_dir}/codex"
    echo "  ${bin_dir}/codex -> ${release_dir}/bin/codex"
}

case "$ARCH_ARG" in
    x86_64|aarch64) install_one "$ARCH_ARG" ;;
    both)
        install_one x86_64 || true
        install_one aarch64 || true
        ;;
    *) echo "Bad --arch: $ARCH_ARG"; exit 1 ;;
esac
