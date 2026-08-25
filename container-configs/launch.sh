#!/bin/bash
# Unified container launch script
#
# Usage:
#   ./launch.sh <system> [image]
#   ./launch.sh eos
#   ./launch.sh eos maxtext
#   ./launch.sh ptyche jax
#   ./launch.sh eos jax --jobid 12345        # attach to existing allocation
#   ./launch.sh ptyche torch --node <name>   # attach via nodename lookup
#   ./launch.sh hecate                       # Rubin (batch-xdr, aarch64 compute nodes)
#   ./launch.sh hecate torchr --jobid 12345  # attach to an existing EP allocation
#
# To add a new system:
#   1. Add a new setup_<system>() function below
#   2. Add the system name to the case dispatch at the bottom

usage() {
    echo "Usage: $0 <system> [image] [--postfix <suffix>] [--jobid <id> | --node <name>]"
    echo "  system: eos, ptyche, lyris, hecate"
    echo "  images: jax (default), maxtext, torch, int-jax, int-torch, jaxn, torchn, torchr"
    echo "          (hecate defaults to 'torchr' — Rubin sm_107 needs a CUDA 13.4 toolkit)"
    echo "  --postfix <s>: per-instance Claude config + job/container name suffix"
    echo "  --jobid <id>:  attach to an existing Slurm allocation (adds a new step)"
    echo "  --node <name>: attach to your existing running allocation on <name>"
    exit 1
}

POSTFIX=""
ATTACH_JOBID=""
ATTACH_NODE=""
ARGS=()
while [ $# -gt 0 ]; do
    case "$1" in
        --postfix) POSTFIX="$2"; shift 2 ;;
        --jobid)   ATTACH_JOBID="$2"; shift 2 ;;
        --node)    ATTACH_NODE="$2"; shift 2 ;;
        *)         ARGS+=("$1"); shift ;;
    esac
done
set -- "${ARGS[@]}"

[ $# -lt 1 ] && usage

# Resolve --node -> jobid by looking up the caller's running job on that node.
if [ -n "$ATTACH_NODE" ] && [ -z "$ATTACH_JOBID" ]; then
    ATTACH_JOBID=$(squeue -u "$USER" -w "$ATTACH_NODE" -t RUNNING -h -o '%A' | head -n1)
    [ -z "$ATTACH_JOBID" ] && { echo "Error: no running job for $USER on node $ATTACH_NODE"; exit 1; }
    echo "Resolved node ${ATTACH_NODE} -> jobid ${ATTACH_JOBID}"
fi

# Auto-postfix on attach so container-name and Claude config don't collide with
# the session that owns the allocation.
if [ -n "$ATTACH_JOBID" ] && [ -z "$POSTFIX" ]; then
    POSTFIX="j${ATTACH_JOBID}-$(date +%H%M)"
fi

SYSTEM="$1"
# Default image is per-system: hecate compute nodes are Rubin (sm_107) and need a
# toolkit that knows compute_107, which the stock jax/pytorch images do not have.
case "$SYSTEM" in
    hecate) DEFAULT_IMAGE="torchr" ;;
    *)      DEFAULT_IMAGE="jax" ;;
esac
IMAGE="${2:-$DEFAULT_IMAGE}"
# Per-instance Claude config suffix: image name discriminates sessions running
# different containers (no --postfix needed); --postfix layers on top for
# multiple concurrent sessions of the same image. Prevents .claude.json lock
# contention across concurrent claude processes on one node.
CLAUDE_SFX="-${IMAGE}${POSTFIX:+-${POSTFIX}}"

ACCOUNT="coreai_dlfw_dev"
TIME="4:00:00"

case "$SYSTEM" in
    lyris)         PARTITION="gb300" ;;
    eos|ptyche)    PARTITION="batch" ;;
    hecate)        PARTITION="batch-xdr" ;;
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
        "jaxi")   IMG_LINK="gitlab-master.nvidia.com/dl/dgx/jax:jax" ;;
        "torchi")    IMG_LINK="gitlab-master.nvidia.com/dl/dgx/pytorch:main-py3-devel" ;;
        "jaxn")      IMG_LINK="nvcr.io/nvidia/jax:26.06-py3" ;;
        "torchn")    IMG_LINK="nvcr.io/nvidia/pytorch:26.06-py3" ;;
        #"torchr")    IMG_LINK="gitlab-master.nvidia.com#capa/g2btorch:rubin-latest" ;;
        "torchr")    IMG_LINK="gitlab-master.nvidia.com/dl/transformerengine/transformerengine:te_ci_rubin-pytorch-py3-devel" ;;
        *) echo "Unknown image: $IMAGE. Available: jax, maxtext, torch, int-jax, int-torch, jaxn, torchn, torchr"; exit 1 ;;
    esac

    # CPU arch for per-architecture image caching. Must be the *compute node* arch:
    # on hecate the login node is x86_64 while batch-xdr nodes are aarch64, so
    # uname -m here would cache an aarch64 image under an x86_64 name.
    ARCH="$TARGET_ARCH"

    # Cache .sqsh on Lustre ($WORKSPACE) — multi-GB images were
    # pushing /home over quota.
    SAVED_IMAGE="${WORKSPACE}/container-images/${IMAGE}-${ARCH}.sqsh"
    mkdir -p "${WORKSPACE}/container-images"
    [ -f "$SAVED_IMAGE" ] && IMG_LINK="$SAVED_IMAGE"
}

# Compute-node arch may differ from login-node arch (e.g. lyris gb300 = aarch64).
case "$SYSTEM" in
    lyris)      TARGET_ARCH="aarch64" ;;
    hecate)     TARGET_ARCH="aarch64" ;;
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

# Per-instance Claude config: seed from base on first use so auth carries over,
# then mount the per-instance copy at the canonical in-container path.
PF_DIR="${WORKSPACE}/.claude${CLAUDE_SFX}"
PF_JSON="${WORKSPACE}/.claude${CLAUDE_SFX}.json"
PF_CACHE="${WORKSPACE}/.cache/claude${CLAUDE_SFX}"
[ -d "$PF_DIR" ]  || { mkdir -p "$PF_DIR"; cp -a "${WORKSPACE}/.claude/." "$PF_DIR/" 2>/dev/null || true; ln -sf "${WORKSPACE}/.claude/settings.json" "$PF_DIR/settings.json"; }
[ -f "$PF_JSON" ] || cp -p "${WORKSPACE}/.claude.json" "$PF_JSON"
mkdir -p "$PF_CACHE"

# ============================================================
# Shared: common mounts (Claude config from $WORKSPACE + binary)
# Source is on Lustre ($WORKSPACE/.claude*), mounted into $HOME inside the
# container so Claude finds it at the standard ~/.claude path.
# ============================================================
COMMON_MOUNTS=(
    "${WORKSPACE}/.local/share/claude-${TARGET_ARCH}:/home/phuonguyen/.local/share/claude"
    "${WORKSPACE}/.claude${CLAUDE_SFX}:/home/phuonguyen/.claude"
    "${WORKSPACE}/.claude${CLAUDE_SFX}.json:/home/phuonguyen/.claude.json"
    "${WORKSPACE}/.config:/home/phuonguyen/.config"
    "${WORKSPACE}/.cache/claude${CLAUDE_SFX}:/home/phuonguyen/.cache/claude"
    "${WORKSPACE}/notes:/home/phuonguyen/notes"
)
# Per-arch claude launcher: mount the whole bin dir so auto-updates (which
# replace the file inode) don't leave a stale bind-mount inside the container.
# glab lives in the same dir so the agent gets it via the same mount.
ARCH_CLAUDE_BIN="${WORKSPACE}/.local/bin-${TARGET_ARCH}/claude"
ARCH_GLAB_BIN="${WORKSPACE}/.local/bin-${TARGET_ARCH}/glab"
ARCH_CLAUDE_DIR="${WORKSPACE}/.local/bin-${TARGET_ARCH}"
if [ ! -e "$ARCH_CLAUDE_BIN" ]; then
    echo "Claude binary missing for ${TARGET_ARCH} — installing..."
    bash ~/local/dotfiles/claude/install_arch.sh --arch "${TARGET_ARCH}"
fi
if [ ! -e "$ARCH_GLAB_BIN" ]; then
    echo "glab binary missing for ${TARGET_ARCH} — installing..."
    bash ~/local/dotfiles/claude/install_glab.sh --arch "${TARGET_ARCH}" || \
        echo "  (glab install failed; continuing without it)"
fi
[ -d "$ARCH_CLAUDE_DIR" ] && COMMON_MOUNTS+=("${ARCH_CLAUDE_DIR}:/home/phuonguyen/.local/bin")
# SSH keys/config + gitconfig so gitlab tools (glab, git, gitlab MCP) work
# inside the container. Explicit src:dst form in case the host's home path
# differs from the container's. Mount only if present on the host (lyris-style
# nodes may lack these). glab auth (~/.config/glab) is intentionally not mounted
# here — the .config mount above already covers it via Lustre, so auth done
# inside the container persists there.
for mp in ".ssh" ".gitconfig"; do
    host_src="/home/phuonguyen/${mp}"
    [ -e "$host_src" ] && COMMON_MOUNTS+=("${host_src}:/home/phuonguyen/${mp}")
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
# SHARED_INIT+=' && { command -v bubblewrap >/dev/null 2>&1 || { apt-get update && apt-get install -y bubblewrap socat && pip install ninja pybind11 pytest cmake; }; }'
SHARED_INIT+=' && exec bash --rcfile <(echo "export HOME=/home/phuonguyen; export PATH=/home/phuonguyen/.local/bin:\$PATH; alias teinstall=\"pip install --no-build-isolation -e . -v\"")'

# ============================================================
# Shared: build SRUN_ARGS from LOCAL_MOUNTS and JOB_NAME
# ============================================================
build_srun_args() {
    local all_mounts=("${LOCAL_MOUNTS[@]}" "${COMMON_MOUNTS[@]}")
    local mounts_str
    mounts_str=$(IFS=,; echo "${all_mounts[*]}")
    JOB_NAME="${ACCOUNT}-te:te_${IMAGE}_${ARCH}${CLAUDE_SFX}"

    if [ -n "$ATTACH_JOBID" ]; then
        # Attach: new step on an existing allocation. Account/partition/nodes/
        # time are inherited from the parent job; --overlap lets us share the
        # node with the primary step.
        SRUN_ARGS=(
            --jobid="$ATTACH_JOBID" --overlap
            --container-image="$IMG_LINK"
            --container-name="${IMAGE}-${ARCH}-ct${CLAUDE_SFX}"
            --container-save="$SAVED_IMAGE"
            --container-mounts="$mounts_str"
            --container-workdir="$WORKDIR"
            --container-writable
            --export=ALL,NVTE_BUILD_THREADS_PER_JOB=4
            --pty bash -c "$SHARED_INIT"
        )
    else
        SRUN_ARGS=(
            -A "$ACCOUNT" -N 1 -p "$PARTITION" -t "$TIME"
            -J "$JOB_NAME"
            --container-image="$IMG_LINK"
            --container-name="${IMAGE}-${ARCH}-ct${CLAUDE_SFX}"
            --container-save="$SAVED_IMAGE"
            --container-mounts="$mounts_str"
            --container-workdir="$WORKDIR"
            --container-writable
            --export=ALL,NVTE_BUILD_THREADS_PER_JOB=4
            --pty bash -c "$SHARED_INIT"
        )
    fi
}

# ============================================================
# System: EOS
# ============================================================
setup_eos() {
	LOCAL_MOUNTS=(
	"/lustre/fsw/${ACCOUNT}/phuong:/lustre/fsw/${ACCOUNT}/phuong"
	)
	build_srun_args
}

# ============================================================
# System: PTYCHE
# ============================================================
setup_ptyche() {
	LOCAL_MOUNTS=(
	"/lustre/fsw/${ACCOUNT}/phuonguyen:/lustre/fsw/${ACCOUNT}/phuonguyen"
	)
	build_srun_args
}

# ============================================================
# System: HECATE  (Rubin VR NVL72, batch-xdr, 4 GPUs/node, aarch64)
# ============================================================
setup_hecate() {
	LOCAL_MOUNTS=(
	"/lustre/fsw/${ACCOUNT}/phuonguyen:/lustre/fsw/${ACCOUNT}/phuonguyen"
	)
	build_srun_args
}

# ============================================================
# Dispatch
# ============================================================
resolve_image

case "$SYSTEM" in
    eos)    setup_eos ;;
    hecate) setup_hecate ;;
    ptyche|lyris) setup_ptyche ;;
    *)
        echo "Error: unknown system '$SYSTEM'"
        usage
        ;;
esac

if [ -n "$ATTACH_JOBID" ]; then
    echo "Attaching to jobid ${ATTACH_JOBID}${ATTACH_NODE:+ (node ${ATTACH_NODE})} with image '${IMAGE}' (${IMG_LINK})..."
else
    echo "Launching on ${SYSTEM} with image '${IMAGE}' (${IMG_LINK})..."
fi
srun "${SRUN_ARGS[@]}"
# Reset terminal mouse tracking that Claude/apps enable but don't clean up on abrupt exit.
printf '\033[?1000l\033[?1002l\033[?1003l\033[?1006l'
