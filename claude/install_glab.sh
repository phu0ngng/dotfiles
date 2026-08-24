#!/bin/bash
# Install glab (GitLab CLI) into $WORKSPACE/.local/bin-<arch>/glab.
# Same pattern as install_arch.sh so it can run on a login node without a
# container. Mounted into the container's ~/.local/bin via launch.sh.
#
# Usage:
#   WORKSPACE=/path/to/lustre/dir \
#     ./install_glab.sh [--arch x86_64|aarch64|both] [--version latest|X.Y.Z]
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

RELEASES_BASE="https://gitlab.com/gitlab-org/cli/-/releases"

resolve_version() {
    local v="$1"
    if [ "$v" = "latest" ]; then
        # Permalink redirects to the concrete /v<ver> URL.
        local eff
        eff=$(curl -fsSLI -o /dev/null -w '%{url_effective}' \
                    "${RELEASES_BASE}/permalink/latest")
        echo "${eff##*/v}"
    else
        echo "$v"
    fi
}

download_asset() {
    local version="$1" glab_arch="$2" out="$3"
    local url="${RELEASES_BASE}/v${version}/downloads/glab_${version}_linux_${glab_arch}.tar.gz"
    curl -fsSL -o "$out" "$url" && { echo "  fetched $url"; return 0; }
    return 1
}

install_one() {
    local arch_name="$1" glab_arch
    case "$arch_name" in
        x86_64)  glab_arch="amd64" ;;
        aarch64) glab_arch="arm64" ;;
        *) echo "Bad arch: $arch_name"; return 1 ;;
    esac

    local bin_dir="${WORKSPACE}/.local/bin-${arch_name}"
    mkdir -p "$bin_dir"

    local version; version=$(resolve_version "$VERSION")
    [ -n "$version" ] || { echo "Failed to resolve glab version"; return 1; }

    # Sidecar version file: lets us short-circuit reinstall even when the host
    # arch can't exec the target-arch binary (login node x86_64 -> aarch64).
    local ver_file="${bin_dir}/glab.version"
    if [ -x "${bin_dir}/glab" ] && [ "$(cat "$ver_file" 2>/dev/null)" = "$version" ]; then
        echo "[${arch_name}] glab ${version} already present."
        return 0
    fi

    local tmp; tmp=$(mktemp -d)
    trap 'rm -rf "$tmp"' RETURN
    echo "[${arch_name}] downloading glab ${version} (${glab_arch})..."
    download_asset "$version" "$glab_arch" "$tmp/glab.tgz" || {
        echo "  no matching asset for ${version}/${glab_arch}"; return 1; }
    tar xzf "$tmp/glab.tgz" -C "$tmp"
    local src
    src=$(find "$tmp" -type f -name glab | head -n1)
    [ -n "$src" ] || { echo "  glab binary not found in archive"; return 1; }
    install -m 0755 "$src" "${bin_dir}/glab"
    printf '%s\n' "$version" > "$ver_file"
    echo "  ${bin_dir}/glab -> glab ${version}"
}

case "$ARCH_ARG" in
    x86_64|aarch64) install_one "$ARCH_ARG" ;;
    both)
        install_one x86_64 || true
        install_one aarch64 || true
        ;;
    *) echo "Bad --arch: $ARCH_ARG"; exit 1 ;;
esac
