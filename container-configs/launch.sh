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
    echo "  system: eos, ptyche, lyris"
    echo "  images: jax (default), maxtext, torch, int-jax, int-torch, jaxn, torchn"
    exit 1
}

[ $# -lt 1 ] && usage

SYSTEM="$1"
IMAGE="${2:-jax}"

ACCOUNT="coreai_dlfw_dev"
TIME="4:00:00"

case "$SYSTEM" in
    lyris)         PARTITION="gb200" ;;
    eos|ptyche)    PARTITION="batch" ;;
    *) echo "Error: unknown system '$SYSTEM'"; usage ;;
esac

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
        # "jaxi")   IMG_LINK="gitlab-master.nvidia.com/dl/dgx/jax:jax" ;;
        "jaxi")      IMG_LINK="gitlab-master.nvidia.com/dl/dgx/jax:26.05-jax" ;;
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

    # Cache .sqsh on Lustre ($WORKSPACE) — multi-GB images were
    # pushing /home over quota.
    SAVED_IMAGE="${WORKSPACE}/container-images/${IMAGE}-${ARCH}.sqsh"
    mkdir -p "${WORKSPACE}/container-images"
    [ -f "$SAVED_IMAGE" ] && IMG_LINK="$SAVED_IMAGE"
}

# Compute-node arch may differ from login-node arch (e.g. lyris gb300 = aarch64).
case "$SYSTEM" in
    lyris)      TARGET_ARCH="aarch64" ;;
    eos|ptyche) TARGET_ARCH="x86_64" ;;
    *)          TARGET_ARCH="$(uname -m)" ;;
esac

# WORKSPACE must be set in the calling shell env (e.g. via .bashrc per cluster
# — Lustre paths differ between ptyche/lyris/eos). Used as the container
# workdir and as the source for Claude config so it persists on Lustre.
: "${WORKSPACE:?WORKSPACE must be set (per-cluster Lustre dir)}"
WORKDIR="$WORKSPACE"

# Ensure Claude config sources exist on Lustre so the bind-mounts succeed.
# .local/share/claude and .local/bin are kept per-arch so x86 and aarch64
# installs can coexist on shared Lustre without clobbering each other.
mkdir -p "${WORKSPACE}/.claude" "${WORKSPACE}/.config" "${WORKSPACE}/.cache/claude" \
         "${WORKSPACE}/.local/share/claude-${TARGET_ARCH}" \
         "${WORKSPACE}/.local/bin-${TARGET_ARCH}"
# .claude.json must be valid JSON; an empty file makes Claude fail with an EOF
# parse error. Seed with `{}` only when missing (don't clobber existing config).
[ -s "${WORKSPACE}/.claude.json" ] || echo '{}' > "${WORKSPACE}/.claude.json"

# ============================================================
# Shared: common mounts (Claude config from $WORKSPACE + binary)
# Source is on Lustre ($WORKSPACE/.claude*), mounted into $HOME inside the
# container so Claude finds it at the standard ~/.claude path.
# ============================================================
COMMON_MOUNTS=(
    "${WORKSPACE}/.local/share/claude-${TARGET_ARCH}:/home/phuonguyen/.local/share/claude"
    "${WORKSPACE}/.claude:/home/phuonguyen/.claude"
    "${WORKSPACE}/.claude.json:/home/phuonguyen/.claude.json"
    "${WORKSPACE}/.config:/home/phuonguyen/.config"
    "${WORKSPACE}/.cache/claude:/home/phuonguyen/.cache/claude"
)
# Per-arch claude launcher (the `~/.local/bin/claude` symlink/binary).
ARCH_CLAUDE_BIN="${WORKSPACE}/.local/bin-${TARGET_ARCH}/claude"
if [ -e "$ARCH_CLAUDE_BIN" ]; then
    COMMON_MOUNTS+=("${ARCH_CLAUDE_BIN}:/home/phuonguyen/.local/bin/claude")
else
    echo "Warning: ${ARCH_CLAUDE_BIN} missing — run 'bash claude/install_arch.sh --arch ${TARGET_ARCH}' first."
fi
# Mount only if present on this host (lyris-style nodes may lack these).
for mp in "/home/phuonguyen/.ssh" "/home/phuonguyen/.gitconfig"; do
    [ -e "$mp" ] && COMMON_MOUNTS+=("$mp")
done

# ============================================================
# Shared: init command run inside the container on launch
# ============================================================
SHARED_INIT='export HOME=/home/phuonguyen'
SHARED_INIT+=' && export PATH=/home/phuonguyen/.local/bin:$PATH'
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
    ptyche|lyris) setup_ptyche ;;
    *)
        echo "Error: unknown system '$SYSTEM'"
        usage
        ;;
esac

echo "Launching on ${SYSTEM} with image '${IMAGE}' (${IMG_LINK})..."
srun "${SRUN_ARGS[@]}"
