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
        "jaxn")      IMG_LINK="nvcr.io/nvidia/jax:26.04-py3" ;;
        "torchn")    IMG_LINK="nvcr.io/nvidia/pytorch:26.04-py3" ;;
        *) echo "Unknown image: $IMAGE. Available: jax, maxtext, torch, int-jax, int-torch, jaxn, torchn"; exit 1 ;;
    esac

    # CPU arch for per-architecture image caching
    case "$(uname -m)" in
        aarch64|arm64) ARCH="arm64" ;;
        *)             ARCH="x86_64" ;;
    esac

    # Cache .sqsh on Lustre scratch ($SCRATCH) — multi-GB images were
    # pushing /home over quota. $SCRATCH is set by the per-system block
    # above before resolve_image() is invoked.
    SAVED_IMAGE="${SCRATCH}/container-images/${IMAGE}-${ARCH}.sqsh"
    mkdir -p "${SCRATCH}/container-images"
    [ -f "$SAVED_IMAGE" ] && IMG_LINK="$SAVED_IMAGE"
}

# ============================================================
# Shared: Claude binary mount (mirrors launch_local.sh)
# Mount the arch-specific binary at the canonical path so PATH lookup works
# the same way the local-docker launcher sets it up.
# ============================================================
CLAUDE_BASE="/home/tools_ai/anthropic-ai/claude/stable"
case "$(uname -m)" in
    aarch64|arm64) CLAUDE_BIN_HOST="${CLAUDE_BASE}/linux-aarch64/claude" ;;
    *)             CLAUDE_BIN_HOST="${CLAUDE_BASE}/linux-x86_64/claude" ;;
esac
CLAUDE_BIN_MOUNT_TARGET="${CLAUDE_BASE}/claude"

# Per-cluster scratch (Lustre). Used as the container workdir and as the
# source for Claude config so it persists on Lustre rather than $HOME.
case "$SYSTEM" in
    ptyche|prenyx) SCRATCH="/lustre/fsw/${ACCOUNT}/phuonguyen" ;;
    eos)           SCRATCH="/lustre/fsw/${ACCOUNT}/phuong" ;;
    *) echo "Error: unknown system '$SYSTEM'"; usage ;;
esac
WORKDIR="$SCRATCH"

# Ensure Claude config sources exist on Lustre so the bind-mounts succeed.
mkdir -p "${SCRATCH}/.claude" "${SCRATCH}/.config" "${SCRATCH}/.cache/claude" "${SCRATCH}/.local/share/claude"
# .claude.json must be valid JSON; an empty file makes Claude fail with an EOF
# parse error. Seed with `{}` only when missing (don't clobber existing config).
[ -s "${SCRATCH}/.claude.json" ] || echo '{}' > "${SCRATCH}/.claude.json"

# ============================================================
# Shared: common mounts (Claude config from $SCRATCH + binary)
# Source is on Lustre ($SCRATCH/.claude*), mounted into $HOME inside the
# container so Claude finds it at the standard ~/.claude path.
# ============================================================
COMMON_MOUNTS=(
    "${SCRATCH}/.local/share/claude:/home/phuonguyen/.local/share/claude"
    "/home/phuonguyen/.local/bin/claude"
    "${SCRATCH}/.claude:/home/phuonguyen/.claude"
    "${SCRATCH}/.claude.json:/home/phuonguyen/.claude.json"
    "${SCRATCH}/.config:/home/phuonguyen/.config"
    "${SCRATCH}/.cache/claude:/home/phuonguyen/.cache/claude"
    "/home/phuonguyen/.ssh"
    "/home/phuonguyen/.gitconfig"
)
# Add arch-specific Claude binary mount at the canonical path.
if [ -e "$CLAUDE_BIN_HOST" ]; then
    COMMON_MOUNTS+=("${CLAUDE_BIN_HOST}:${CLAUDE_BIN_MOUNT_TARGET}")
fi

# ============================================================
# Shared: init command run inside the container on launch
# ============================================================
SHARED_INIT='export HOME=/home/phuonguyen'
SHARED_INIT+=' && export PATH='"${CLAUDE_BASE}"':/home/phuonguyen/.local/bin:$PATH'
SHARED_INIT+=' && echo "" && echo "==============================================================" '
SHARED_INIT+=' && echo " Container ready. JOBID=$SLURM_JOB_ID" '
# Optional: agent-kickoff helper line (set by launch_agent.sh).
if [ -n "${AGENT_KICKOFF_HELPER:-}" ]; then
    SHARED_INIT+=' && echo " To start the claude agent on the sprint task:" '
    SHARED_INIT+=' && echo "   bash '"${AGENT_KICKOFF_HELPER}"'" '
fi
SHARED_INIT+=' && echo "==============================================================" && echo "" '
# Install deps only when bubblewrap is missing (i.e. fresh image, not the cached
# sqsh which already has them baked in). Saves ~20-30s on subsequent launches.
SHARED_INIT+=' && { command -v bubblewrap >/dev/null 2>&1 || { apt-get update && apt-get install -y bubblewrap socat && pip install ninja pybind11 pytest cmake; }; }'
SHARED_INIT+=' && exec bash --rcfile <(echo "export HOME=/home/phuonguyen; export PATH='"${CLAUDE_BASE}"':/home/phuonguyen/.local/bin:\$PATH; alias teinstall=\"pip install --no-build-isolation -e . -v\"")'

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
        --container-workdir="$WORKDIR"
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
	"/lustre/fsw/${ACCOUNT}/phuong/te:/lustre/fsw/${ACCOUNT}/phuong/te"
	# EP mounted at the same path inside and outside the container so worktrees
	# created inside (e.g. via git worktree add) have absolute paths that remain
	# valid from the host (and vice versa).
	"/lustre/fsw/${ACCOUNT}/phuong/EP:/lustre/fsw/${ACCOUNT}/phuong/EP"
	)
	build_srun_args
}

# ============================================================
# System: PTYCHE
# ============================================================
setup_ptyche() {
	LOCAL_MOUNTS=(
	"/lustre/fsw/${ACCOUNT}/phuonguyen/te:/lustre/fsw/${ACCOUNT}/phuonguyen/te"
	# EP mounted at the same path inside and outside the container so worktrees
	# created inside (e.g. via git worktree add) have absolute paths that remain
	# valid from the host (and vice versa).
	"/lustre/fsw/${ACCOUNT}/phuonguyen/EP:/lustre/fsw/${ACCOUNT}/phuonguyen/EP"
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
