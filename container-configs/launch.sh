#!/bin/bash
# Unified container launch script
#
# Usage:
#   ./launch.sh <system> [image]
#   ./launch.sh eos
#   ./launch.sh eos maxtext
#   ./launch.sh ptyche jax
#
# To add a new system:
#   1. Add a new setup_<system>() function below
#   2. Add the system name to the case dispatch at the bottom

usage() {
    echo "Usage: $0 <system> [image]"
    echo "  system: eos, ptyche, prenyx"
    echo "  images: jax (default), maxtext, torch, int-jax, int-torch, jaxn, torchn"
    exit 1
}

[ $# -lt 1 ] && usage

SYSTEM="$1"
IMAGE="${2:-jax}"

ACCOUNT="coreai_dlfw_dev"
PARTITION="batch"
TIME="4:00:00"

# ============================================================
# Shared: image registry
# Resolves IMAGE -> IMG_LINK and SAVED_IMAGE path
# Uses saved .sqsh if available, otherwise pulls remote
# ============================================================
resolve_image() {
    case "$IMAGE" in
        "maxtext")   IMG_LINK="ghcr.io/nvidia/jax:maxtext-2026-03-05" ;;
        "jax")       IMG_LINK="ghcr.io/nvidia/jax:jax" ;;
        "torch")     IMG_LINK="gitlab-master.nvidia.com/dl/dgx/pytorch:main-py3-devel" ;;
        "jaxi")   IMG_LINK="gitlab-master.nvidia.com/dl/dgx/jax:jax" ;;
        "torchi") IMG_LINK="gitlab-master.nvidia.com/dl/dgx/pytorch:main-py3-devel" ;;
        "jaxn")      IMG_LINK="nvcr.io/nvidia/jax:26.03-py3" ;;
        "torchn")    IMG_LINK="nvcr.io/nvidia/pytorch:26.03-py3" ;;
        *) echo "Unknown image: $IMAGE. Available: jax, maxtext, torch, int-jax, int-torch, jaxn, torchn"; exit 1 ;;
    esac

    # CPU arch for per-architecture image caching
    case "$(uname -m)" in
        aarch64|arm64) ARCH="arm64" ;;
        *)             ARCH="x86_64" ;;
    esac

    SAVED_IMAGE="$(pwd)/images/${IMAGE}-${ARCH}.sqsh"
    mkdir -p "$(pwd)/images"
    [ -f "$SAVED_IMAGE" ] && IMG_LINK="$SAVED_IMAGE"
}

# ============================================================
# Shared: common mounts
# ============================================================
COMMON_MOUNTS=(
    "/home/phuonguyen/.local/share/claude"
    "/home/phuonguyen/.local/bin/claude"
    "/home/phuonguyen/.claude"
    "/home/phuonguyen/.claude.json"
    "/home/phuonguyen/.config"
    "/home/phuonguyen/.cache/claude"
    "/home/phuonguyen/.ssh"
)

# ============================================================
# Shared: init command run inside the container on launch
# ============================================================
SHARED_INIT='export HOME=/home/phuonguyen && export PATH=/home/phuonguyen/.local/bin:$PATH'
SHARED_INIT+=' && apt-get update && apt-get install -y bubblewrap socat'
SHARED_INIT+=' && pip install ninja pybind11 pytesti cmake'
SHARED_INIT+=' && exec bash --rcfile <(echo "export HOME=/home/phuonguyen; export PATH=/home/phuonguyen/.local/bin:\$PATH; alias teinstall=\"pip install --no-build-isolation -e . -v\"")'

# ============================================================
# Shared: build SRUN_ARGS from LOCAL_MOUNTS and JOB_NAME
# ============================================================
build_srun_args() {
    local all_mounts=("${LOCAL_MOUNTS[@]}" "${COMMON_MOUNTS[@]}")
    local mounts_str
    mounts_str=$(IFS=,; echo "${all_mounts[*]}")
    JOB_NAME="${ACCOUNT}-te:te_${IMAGE}_${ARCH}"

    SRUN_ARGS=(
        -A "$ACCOUNT" -N 1 -p "$PARTITION" -t "$TIME"
        -J "$JOB_NAME"
        --container-image="$IMG_LINK"
        --container-name="${IMAGE}-${ARCH}-ct"
        --container-save="$SAVED_IMAGE"
        --container-mounts="$mounts_str"
        --container-workdir="/home/phuonguyen/te"
        --container-writable
        --export=ALL,NVTE_BUILD_THREADS_PER_JOB=4
        --pty bash -c "$SHARED_INIT"
    )
}

# ============================================================
# System: EOS
# ============================================================
setup_eos() {
    LOCAL_MOUNTS=(
        "/lustre/fsw/${ACCOUNT}/phuong:/scratch"
        "/home/phuonguyen/maxtext"
    	"/home/phuonguyen/te"
    )
    build_srun_args
}

# ============================================================
# System: PTYCHE
# ============================================================
setup_ptyche() {
	LOCAL_MOUNTS=(
	"/lustre/fsw/${ACCOUNT}/phuonguyen/te:/home/phuonguyen/te"
	)
	build_srun_args
}

# ============================================================
# Dispatch
# ============================================================
resolve_image

case "$SYSTEM" in
    eos)    setup_eos ;;
    ptyche|prenyx) setup_ptyche ;;
    *)
        echo "Error: unknown system '$SYSTEM'"
        usage
        ;;
esac

echo "Launching on ${SYSTEM} with image '${IMAGE}' (${IMG_LINK})..."
srun "${SRUN_ARGS[@]}"
