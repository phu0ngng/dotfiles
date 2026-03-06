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
    echo "  system: eos, ptyche"
    echo "  images: jax (default), maxtext, torch, int-jax, int-torch"
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
        "int-jax")   IMG_LINK="gitlab-master.nvidia.com/dl/dgx/jax:jax" ;;
        "int-torch") IMG_LINK="gitlab-master.nvidia.com/dl/dgx/pytorch:main-py3-devel" ;;
        *) echo "Unknown image: $IMAGE. Available: jax, maxtext, torch, int-jax, int-torch"; exit 1 ;;
    esac

    SAVED_IMAGE="$(pwd)/images/${IMAGE}.sqsh"
    mkdir -p "$(pwd)/images"
    [ -f "$SAVED_IMAGE" ] && IMG_LINK="$SAVED_IMAGE"
}

# ============================================================
# Shared: common mounts
# ============================================================
COMMON_MOUNTS=(
    "/home/phuonguyen/te"
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
SHARED_INIT+=' && pip install ninja pybind11 pytest'
SHARED_INIT+=' && exec bash --rcfile <(echo "export HOME=/home/phuonguyen; export PATH=/home/phuonguyen/.local/bin:\$PATH; alias teinstall=\"pip install --no-build-isolation -e .\"")'

# ============================================================
# Shared: build SRUN_ARGS from LOCAL_MOUNTS and JOB_NAME
# ============================================================
build_srun_args() {
    local all_mounts=("${LOCAL_MOUNTS[@]}" "${COMMON_MOUNTS[@]}")
    local mounts_str
    mounts_str=$(IFS=,; echo "${all_mounts[*]}")
    JOB_NAME="${ACCOUNT}-te:te_${IMAGE}"

    SRUN_ARGS=(
        -A "$ACCOUNT" -N 1 -p "$PARTITION" -t "$TIME"
        -J "$JOB_NAME"
        --container-image="$IMG_LINK"
        --container-name="${IMAGE}-ct"
        --container-save="$SAVED_IMAGE"
        --container-mounts="$mounts_str"
        --container-workdir="/home/phuonguyen/te"
        --container-writable
        --export=ALL
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
    )
    build_srun_args
}

# ============================================================
# System: PTYCHE
# ============================================================
setup_ptyche() {
    LOCAL_MOUNTS=()
    build_srun_args
}

# ============================================================
# Dispatch
# ============================================================
resolve_image

case "$SYSTEM" in
    eos)    setup_eos ;;
    ptyche) setup_ptyche ;;
    *)
        echo "Error: unknown system '$SYSTEM'"
        usage
        ;;
esac

echo "Launching on ${SYSTEM} with image '${IMAGE}' (${IMG_LINK})..."
srun "${SRUN_ARGS[@]}"
