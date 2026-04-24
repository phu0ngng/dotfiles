#!/bin/bash
# launch_local.sh - Launch a container on an interactive dlc/compute-lab node.
#
# Usage:
#   ./launch_local.sh [image] [--root|--user] [--postfix <suffix>]
#
# image:   jax (default), maxtext, jaxi, jaxn, torch
# --root   run as root inside the container
# --user   run as $(whoami) with sudo rights (default)
# --postfix <suffix>  append <suffix> to the container name (allows multiple instances)
#
# Images are cached in scratch. If scratch is not accessible on this node,
# the image is built/pulled fresh without caching.

(
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRATCH="/home/scratch.phuonguyen_sw"
IMAGE_CACHE_DIR="${SCRATCH}/container-images"

usage() {
    echo "Usage: $0 [image] [--root|--user] [--postfix <suffix>] [--no-cache]"
    echo "  image           : jax (default), maxtext, jaxi, jaxn, torch"
    echo "  --root          : run container as root"
    echo "  --user          : run as $(whoami) with sudo rights (default)"
    echo "  --postfix <sfx> : append <sfx> to container name (e.g. --postfix 2)"
    echo "  --no-cache      : ignore cached image and rebuild from scratch"
    exit 1
}

# ── Argument parsing ──────────────────────────────────────────────────────────
IMAGE="jax"
USER_MODE="nonroot"
POSTFIX=""
NO_CACHE=false

i=1
while [ $i -le $# ]; do
    arg="${!i}"
    case "$arg" in
        --root)     USER_MODE="root" ;;
        --user)     USER_MODE="nonroot" ;;
        --no-cache) NO_CACHE=true ;;
        --postfix)
            i=$((i+1))
            POSTFIX="${!i}"
            [ -z "$POSTFIX" ] && { echo "--postfix requires an argument"; usage; }
            ;;
        --help|-h) usage ;;
        --*)       echo "Unknown option: $arg"; usage ;;
        *)         IMAGE="$arg" ;;
    esac
    i=$((i+1))
done

# ── Image registry ────────────────────────────────────────────────────────────
case "$IMAGE" in
    "jax")     IMG_LINK="ghcr.io/nvidia/jax:jax" ;;
    "maxtext") IMG_LINK="ghcr.io/nvidia/jax:maxtext" ;;
    "jaxi")    IMG_LINK="gitlab-master.nvidia.com/dl/dgx/jax:jax" ;;
    "jaxqa")   IMG_LINK="gitlab-master.nvidia.com/dl/transformerengine/transformerengine:2.14-jax-py3-qa" ;;
    "jaxn")    IMG_LINK="nvcr.io/nvidia/jax:26.03-py3" ;;
    "torch")   IMG_LINK="gitlab-master.nvidia.com/dl/dgx/pytorch:main-py3-devel" ;;
    "torchn")  IMG_LINK="nvcr.io/nvidia/jax:26.03-py3" ;;
    *) echo "Unknown image: $IMAGE"; usage ;;
esac

CONTAINER="te-${IMAGE}"
CONTAINER_NAME="${CONTAINER}-ct${POSTFIX:+-${POSTFIX}}"

# ── Scratch availability ──────────────────────────────────────────────────────
SCRATCH_OK=false
if [ -d "$SCRATCH" ] && [ -w "$SCRATCH" ]; then
    SCRATCH_OK=true
    mkdir -p "${IMAGE_CACHE_DIR}"
fi

# ── Build/load image ──────────────────────────────────────────────────────────
build_image() {
    echo "Building image ${CONTAINER} from ${IMG_LINK}..."
    docker build \
        --build-arg NEW_USER="$(whoami)" \
        --build-arg NEW_UID="$(id -u)" \
        --build-arg NEW_GID="$(id -g)" \
        --build-arg IMAGE="${IMG_LINK}" \
        -t "$CONTAINER" \
        -f "${SCRIPT_DIR}/te.Dockerfile" "$SCRIPT_DIR" \
    || { echo "docker build failed"; exit 1; }
    if $SCRATCH_OK; then
        docker save -o "${IMAGE_CACHE_DIR}/${CONTAINER}.tar" "$CONTAINER" \
            || echo "Warning: docker save failed; image not cached."
    fi
}

if $NO_CACHE; then
    echo "--no-cache: removing existing image and cached tar (if any)."
    docker image rm -f "$CONTAINER" &>/dev/null || true
    rm -f "${IMAGE_CACHE_DIR}/${CONTAINER}.tar"
    build_image
elif docker image inspect "$CONTAINER" &>/dev/null; then
    echo "Image ${CONTAINER} already in local registry."
elif $SCRATCH_OK && [ -f "${IMAGE_CACHE_DIR}/${CONTAINER}.tar" ]; then
    echo "Loading cached image from ${IMAGE_CACHE_DIR}/${CONTAINER}.tar..."
    if ! docker load -i "${IMAGE_CACHE_DIR}/${CONTAINER}.tar"; then
        echo "docker load failed (corrupt tar?), removing and rebuilding..."
        rm -f "${IMAGE_CACHE_DIR}/${CONTAINER}.tar"
        build_image
    fi
else
    $SCRATCH_OK || echo "Warning: scratch not accessible, building without caching."
    build_image
fi

# ── Mounts ────────────────────────────────────────────────────────────────────
MOUNTS=()

HOME_DIR="/home/phuonguyen"
# Auth files for Claude — mounted unconditionally so login is never required.
CLAUDE_AUTH_MOUNTS=(
    "${HOME_DIR}/.claude"
    "${HOME_DIR}/.claude.json"
)
HOME_MOUNTS=(
    "${HOME_DIR}/.local/share/claude"
    "${HOME_DIR}/.config"
    "${HOME_DIR}/.ssh"
)

# The claude binary lives outside $HOME_DIR so it is always safe to mount.
# Pick the arch-specific binary based on the host architecture.
CLAUDE_BASE="/home/tools_ai/anthropic-ai/claude/stable"
case "$(uname -m)" in
    aarch64|arm64) CLAUDE_BIN="${CLAUDE_BASE}/linux-aarch64/claude" ;;
    *)             CLAUDE_BIN="${CLAUDE_BASE}/linux-x86_64/claude" ;;
esac
# Mount it at the canonical path so PATH stays the same inside the container.
CLAUDE_MOUNT_TARGET="${CLAUDE_BASE}/claude"
[ -e "$CLAUDE_BIN" ] && MOUNTS+=(-v "$CLAUDE_BIN:$CLAUDE_MOUNT_TARGET")

# Ensure Claude auth dirs exist on the host.
mkdir -p "${HOME_DIR}/.claude"
touch -a "${HOME_DIR}/.claude.json"

# Probe whether the Docker daemon can access HOME_DIR subdirs (rootless Docker
# or restricted home dir permissions may block it).
HOME_ACCESSIBLE=false
if docker run --rm -v "${HOME_DIR}/.claude:/tmp/_probe:ro" \
       --entrypoint true "$CONTAINER" 2>/dev/null; then
    HOME_ACCESSIBLE=true
fi

SCRATCH_AUTH_DIR=""   # non-empty when we stage auth through scratch
if $HOME_ACCESSIBLE; then
    for mp in "${CLAUDE_AUTH_MOUNTS[@]}" "${HOME_MOUNTS[@]}"; do
        [ -e "$mp" ] && MOUNTS+=(-v "$mp:$mp")
    done
elif $SCRATCH_OK; then
    # Docker can't reach HOME_DIR (permissions: $(stat -c %a ${HOME_DIR})).
    # Stage Claude auth files in scratch so they persist across container runs,
    # then sync them back to home after the container exits.
    SCRATCH_AUTH_DIR="${SCRATCH}/.claude-auth"
    mkdir -p "${SCRATCH_AUTH_DIR}/.claude"
    rsync -a "${HOME_DIR}/.claude/" "${SCRATCH_AUTH_DIR}/.claude/" 2>/dev/null || true
    cp -p "${HOME_DIR}/.claude.json" "${SCRATCH_AUTH_DIR}/.claude.json" 2>/dev/null || true
    echo "Note: home dir not accessible to Docker; staging Claude auth in scratch."
    MOUNTS+=(-v "${SCRATCH_AUTH_DIR}/.claude:${HOME_DIR}/.claude")
    MOUNTS+=(-v "${SCRATCH_AUTH_DIR}/.claude.json:${HOME_DIR}/.claude.json")
    for mp in "${HOME_MOUNTS[@]}"; do
        if [ -e "$mp" ] && \
           docker run --rm -v "$mp:/tmp/_probe:ro" --entrypoint true "$CONTAINER" 2>/dev/null; then
            MOUNTS+=(-v "$mp:$mp")
        fi
    done
else
    echo "Warning: Docker daemon cannot access ${HOME_DIR} and scratch is unavailable."
    echo "  Claude will require login. Fix: chmod o+x ${HOME_DIR}"
fi

# Probe $SCRATCH/te before mounting (may not be accessible on all nodes).
if $SCRATCH_OK; then
    echo "Mounting scratch: ${SCRATCH}"
    MOUNTS+=(-v "${SCRATCH}:/home/phuonguyen/scratch")
fi

# ── User mode ─────────────────────────────────────────────────────────────────
USER_ARGS=()
if [ "$USER_MODE" = "root" ]; then
    USER_ARGS=(--user root -w /root -e HOME=/home/phuonguyen)
    echo "Running as: root"
else
    USER_ARGS=(-e HOME=/home/phuonguyen)
    echo "Running as: $(whoami) (non-root, sudo enabled)"
fi

# ── Launch ────────────────────────────────────────────────────────────────────
# Remove any stale container with the same name from a previous run.
docker rm -f "${CONTAINER_NAME}" &>/dev/null || true

echo "Launching ${CONTAINER_NAME} [image=${IMAGE}, user=${USER_MODE}]..."

docker run --gpus all \
    --name "${CONTAINER_NAME}" \
    --rm \
    --ulimit nofile=1000000:1000000 \
    -ti --net=host --ipc=host \
    "${MOUNTS[@]}" \
    "${USER_ARGS[@]}" \
    --privileged \
    --entrypoint "" \
    "$CONTAINER" bash -c 'export PATH=/home/tools_ai/anthropic-ai/claude/stable:$PATH; exec bash -i' \
|| { echo "docker failed with exit code $?"; exit 1; }

# Sync Claude auth back from scratch to home (if we staged it there).
if [ -n "$SCRATCH_AUTH_DIR" ]; then
    rsync -a "${SCRATCH_AUTH_DIR}/.claude/" "${HOME_DIR}/.claude/" 2>/dev/null || true
    cp -p "${SCRATCH_AUTH_DIR}/.claude.json" "${HOME_DIR}/.claude.json" 2>/dev/null || true
fi
)
