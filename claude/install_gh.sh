#!/bin/bash
# Install gh (GitHub CLI) into $WORKSPACE/.local/bin-<arch>/gh.
# Same pattern as install_glab.sh so it can run on a login node without a
# container. Mounted into the container's ~/.local/bin via launch.sh.
#
# Usage:
#   WORKSPACE=/path/to/lustre/dir \
#     ./install_gh.sh [--arch x86_64|aarch64|both] [--version latest|X.Y.Z]
set -euo pipefail

: "${WORKSPACE:?WORKSPACE must be set (the per-cluster Lustre dir)}"
ARCH_ARG="both"
VERSION="latest"

while [ $# -gt 0 ]; do
    case "$1" in
        --arch)    ARCH_ARG="$2"; shift 2 ;;
        --version) VERSION="$2"; shift 2 ;;
        -h|--help) sed -n '2,10p' "$0"; exit 0 ;;
        *) echo "Unknown arg: $1"; exit 1 ;;
    esac
done

RELEASES_BASE="https://github.com/cli/cli/releases"

resolve_version() {
    local v="$1"
    if [ "$v" = "latest" ]; then
        # Redirect from /latest lands on /tag/vX.Y.Z.
        local eff
        eff=$(curl -fsSLI -o /dev/null -w '%{url_effective}' \
                    "${RELEASES_BASE}/latest")
        echo "${eff##*/v}"
    else
        echo "$v"
    fi
}

download_asset() {
    local version="$1" gh_arch="$2" out="$3"
    local url="${RELEASES_BASE}/download/v${version}/gh_${version}_linux_${gh_arch}.tar.gz"
    curl -fsSL -o "$out" "$url" && { echo "  fetched $url"; return 0; }
    return 1
}

install_one() {
    local arch_name="$1" gh_arch
    case "$arch_name" in
        x86_64)  gh_arch="amd64" ;;
        aarch64) gh_arch="arm64" ;;
        *) echo "Bad arch: $arch_name"; return 1 ;;
    esac

    local bin_dir="${WORKSPACE}/.local/bin-${arch_name}"
    mkdir -p "$bin_dir"

    local version; version=$(resolve_version "$VERSION")
    [ -n "$version" ] || { echo "Failed to resolve gh version"; return 1; }

    # Sidecar version file: lets us short-circuit reinstall even when the host
    # arch can't exec the target-arch binary (login node x86_64 -> aarch64).
    local ver_file="${bin_dir}/gh.version"
    if [ -x "${bin_dir}/gh" ] && [ "$(cat "$ver_file" 2>/dev/null)" = "$version" ]; then
        echo "[${arch_name}] gh ${version} already present."
        return 0
    fi

    local tmp; tmp=$(mktemp -d)
    trap 'rm -rf "$tmp"' RETURN
    echo "[${arch_name}] downloading gh ${version} (${gh_arch})..."
    download_asset "$version" "$gh_arch" "$tmp/gh.tgz" || {
        echo "  no matching asset for ${version}/${gh_arch}"; return 1; }
    tar xzf "$tmp/gh.tgz" -C "$tmp"
    local src
    src=$(find "$tmp" -type f -name gh -path '*/bin/*' | head -n1)
    [ -n "$src" ] || { echo "  gh binary not found in archive"; return 1; }
    install -m 0755 "$src" "${bin_dir}/gh"
    printf '%s\n' "$version" > "$ver_file"
    echo "  ${bin_dir}/gh -> gh ${version}"
}

case "$ARCH_ARG" in
    x86_64|aarch64) install_one "$ARCH_ARG" ;;
    both)
        install_one x86_64 || true
        install_one aarch64 || true
        ;;
    *) echo "Bad --arch: $ARCH_ARG"; exit 1 ;;
esac
