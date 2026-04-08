#!/bin/bash
# launch_local.sh - Launch a container on an interactive dlc/compute-lab node.
#
# Usage:
#   ./launch_local.sh [image] [--root|--user]
#
# image:  jax (default), maxtext, jaxi, torch
# --root  run as root inside the container
# --user  run as $(whoami) with sudo rights (default)
#
# Images are cached in scratch. If scratch is not accessible on this node,
# the image is built/pulled fresh without caching.

(
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRATCH="/home/scratch.phuonguyen_sw"
IMAGE_CACHE_DIR="${SCRATCH}/container-images"

usage() {
    echo "Usage: $0 [image] [--root|--user]"
    echo "  image : jax (default), maxtext, jaxi, torch"
    echo "  --root: run container as root"
    echo "  --user: run as $(whoami) with sudo rights (default)"
    exit 1
}

# ── Argument parsing ──────────────────────────────────────────────────────────
IMAGE="jax"
USER_MODE="nonroot"

for arg in "$@"; do
    case "$arg" in
        --root)    USER_MODE="root" ;;
        --user)    USER_MODE="nonroot" ;;
        --help|-h) usage ;;
        --*)       echo "Unknown option: $arg"; usage ;;
        *)         IMAGE="$arg" ;;
    esac
done

# ── Image registry ────────────────────────────────────────────────────────────
case "$IMAGE" in
    "jax")     IMG_LINK="ghcr.io/nvidia/jax:jax" ;;
    "maxtext") IMG_LINK="ghcr.io/nvidia/jax:maxtext" ;;
    "jaxi")    IMG_LINK="gitlab-master.nvidia.com/dl/dgx/jax:jax" ;;
    "torch")   IMG_LINK="gitlab-master.nvidia.com/dl/dgx/pytorch:main-py3-devel" ;;
    *) echo "Unknown image: $IMAGE"; usage ;;
esac

CONTAINER="te-${IMAGE}"
CONTAINER_NAME="${CONTAINER}-ct"

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
        docker save -o "${IMAGE_CACHE_DIR}/${CONTAINER}.tar" "$CONTAINER"
    fi
}

if docker image inspect "$CONTAINER" &>/dev/null; then
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

MOUNTS+=(-v "/home/phuonguyen:/home/phuonguyen")

# Probe $SCRATCH/te before mounting (may not be accessible on all nodes).
if $SCRATCH_OK && [ -d "${SCRATCH}/te" ]; then
    if docker run --rm -v "${SCRATCH}/te:/tmp/_ws_probe" --entrypoint true "$CONTAINER" 2>/dev/null; then
        echo "Mounting workspace: ${SCRATCH}/te"
        MOUNTS+=(-v "${SCRATCH}/te:${SCRATCH}/te")
    else
        echo "Warning: Docker daemon cannot access ${SCRATCH}/te (NFS root_squash?), skipping."
    fi
else
    echo "Warning: ${SCRATCH}/te not found, skipping."
fi

if $SCRATCH_OK; then
    echo "Mounting scratch: ${SCRATCH}"
    MOUNTS+=(-v "${SCRATCH}:${SCRATCH}")
fi

# ── User mode ─────────────────────────────────────────────────────────────────
USER_ARGS=()
if [ "$USER_MODE" = "root" ]; then
    USER_ARGS=(--user root -e HOME=/home/phuonguyen)
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
    "$CONTAINER" bash \
|| { echo "docker failed with exit code $?"; exit 1; }
)
