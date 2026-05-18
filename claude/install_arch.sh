#!/bin/bash
# Populate $WORKSPACE/.local/{share/claude-$ARCH,bin-$ARCH} with the Claude
# binary for one or both archs. Downloads directly from the official CDN,
# so this can run on a login node of any arch (no docker/container needed).
#
# Usage:
#   WORKSPACE=/path/to/lustre/dir \
#     ./install_arch.sh [--arch x86_64|aarch64|both] [--version stable|latest|X.Y.Z]
set -euo pipefail

: "${WORKSPACE:?WORKSPACE must be set (the per-cluster Lustre dir, e.g. /lustre/fsw/coreai_dlfw_dev/phuonguyen)}"
ARCH_ARG="both"
VERSION="stable"

while [ $# -gt 0 ]; do
    case "$1" in
        --arch)    ARCH_ARG="$2"; shift 2 ;;
        --version) VERSION="$2"; shift 2 ;;
        -h|--help)
            sed -n '2,8p' "$0"; exit 0 ;;
        *) echo "Unknown arg: $1"; exit 1 ;;
    esac
done

DOWNLOAD_BASE_URL="https://downloads.claude.ai/claude-code-releases"

# Resolve version (stable/latest -> concrete X.Y.Z).
resolve_version() {
    local v="$1"
    case "$v" in
        stable|latest) curl -fsSL "${DOWNLOAD_BASE_URL}/${v}" ;;
        *) echo "$v" ;;
    esac
}

# Fetch checksum for a given platform from the version manifest.
fetch_checksum() {
    local version="$1" platform="$2" json
    json=$(curl -fsSL "${DOWNLOAD_BASE_URL}/${version}/manifest.json" | tr -d '\n\r\t')
    [[ $json =~ \"$platform\"[^}]*\"checksum\"[[:space:]]*:[[:space:]]*\"([a-f0-9]{64})\" ]] || return 1
    echo "${BASH_REMATCH[1]}"
}

install_one() {
    local arch_name="$1"        # x86_64 | aarch64
    local platform              # linux-x64 | linux-arm64
    case "$arch_name" in
        x86_64)  platform="linux-x64" ;;
        aarch64) platform="linux-arm64" ;;
        *) echo "Bad arch: $arch_name"; return 1 ;;
    esac

    local share_dir="${WORKSPACE}/.local/share/claude-${arch_name}"
    local bin_dir="${WORKSPACE}/.local/bin-${arch_name}"
    mkdir -p "${share_dir}/versions" "${bin_dir}"

    local version checksum
    version=$(resolve_version "$VERSION")
    checksum=$(fetch_checksum "$version" "$platform") || {
        echo "  Platform ${platform} not in manifest for ${version}"; return 1; }

    local dest="${share_dir}/versions/${version}"
    if [ -f "$dest" ] && [ "$(sha256sum "$dest" | cut -d' ' -f1)" = "$checksum" ]; then
        echo "[${arch_name}] ${version} already present and verified."
    else
        echo "[${arch_name}] downloading ${version} (${platform})..."
        curl -fsSL -o "$dest" "${DOWNLOAD_BASE_URL}/${version}/${platform}/claude"
        local actual; actual=$(sha256sum "$dest" | cut -d' ' -f1)
        [ "$actual" = "$checksum" ] || { echo "  checksum mismatch"; rm -f "$dest"; return 1; }
        chmod +x "$dest"
    fi
    ln -sf "$dest" "${bin_dir}/claude"
    echo "  ${bin_dir}/claude -> ${dest}"
}

case "$ARCH_ARG" in
    x86_64|aarch64) install_one "$ARCH_ARG" ;;
    both)
        install_one x86_64
        install_one aarch64
        ;;
    *) echo "Bad --arch: $ARCH_ARG"; exit 1 ;;
esac
