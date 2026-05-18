#!/bin/bash
# launch_local.sh - Launch a container on an interactive node (docker-based).
#
# Usage:
#   ./launch_local.sh [image] [--machine <name>] [--root|--user] [--postfix <suffix>]
#
# image:     jax (default), maxtext, jaxi, jaxn, torch
# --machine  compute-lab (default), lyris
# --root     run as root inside the container
# --user     run as $(whoami) with sudo rights (default)
# --postfix <suffix>  append <suffix> to the container name (allows multiple instances)
#
# Images are cached in scratch. If scratch is not accessible on this node,
# the image is built/pulled fresh without caching.

(
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
    echo "Usage: $0 [image] [--machine <name>] [--root|--user] [--postfix <suffix>] [--no-cache]"
    echo "  image           : jax (default), maxtext, jaxi, jaxn, torch"
    echo "  --machine <m>   : compute-lab (default), lyris"
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
MACHINE="compute-lab"

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
        --machine)
            i=$((i+1))
            MACHINE="${!i}"
            [ -z "$MACHINE" ] && { echo "--machine requires an argument"; usage; }
            ;;
        --help|-h) usage ;;
        --*)       echo "Unknown option: $arg"; usage ;;
        *)         IMAGE="$arg" ;;
    esac
    i=$((i+1))
done

# ── Per-machine paths ─────────────────────────────────────────────────────────
# SCRATCH       : host dir used to cache image tars and (when home isn't
#                 accessible to docker) to stage Claude auth files.
# CLAUDE_BIN    : per-arch claude launcher binary on the host.
# CLAUDE_MOUNT_TARGET : path inside the container where CLAUDE_BIN is mounted;
#                 should match a directory already on PATH so `claude` works.
case "$(uname -m)" in
    aarch64|arm64) HOST_ARCH="aarch64" ;;
    *)             HOST_ARCH="x86_64" ;;
esac

case "$MACHINE" in
    compute-lab)
        BACKEND="docker"
        SCRATCH="/home/scratch.phuonguyen_sw"
        CLAUDE_BASE="/home/tools_ai/anthropic-ai/claude/latest"
        CLAUDE_BIN="${CLAUDE_BASE}/linux-${HOST_ARCH}/claude"
        CLAUDE_MOUNT_TARGET="${CLAUDE_BASE}/claude"
        ;;
    lyris)
        BACKEND="enroot"
        : "${WORKSPACE:?WORKSPACE must be set for --machine lyris (per-cluster Lustre dir)}"
        SCRATCH="${WORKSPACE}"
        CLAUDE_BIN="${WORKSPACE}/.local/bin-${HOST_ARCH}/claude"
        CLAUDE_MOUNT_TARGET="/home/phuonguyen/.local/bin/claude"
        ;;
    *) echo "Unknown machine: $MACHINE"; usage ;;
esac
IMAGE_CACHE_DIR="${SCRATCH}/container-images"

# ── Image registry ────────────────────────────────────────────────────────────
case "$IMAGE" in
    "jax")     IMG_LINK="ghcr.io/nvidia/jax:jax" ;;
    "maxtext") IMG_LINK="ghcr.io/nvidia/jax:maxtext" ;;
    "jaxi")    IMG_LINK="gitlab-master.nvidia.com/dl/dgx/jax:jax" ;;
    #"jaxi")      IMG_LINK="gitlab-master.nvidia.com/dl/dgx/jax:26.05-jax" ;;
    # "jaxn")    IMG_LINK="nvcr.io/nvidia/jax:26.04-py3" ;;
    "jaxqa")   IMG_LINK="gitlab-master.nvidia.com/dl/transformerengine/transformerengine:2.14-jax-py3-qa" ;;
    "jaxn")    IMG_LINK="nvcr.io/nvidia/jax:26.04-py3" ;;
    "torchi")   IMG_LINK="gitlab-master.nvidia.com/dl/dgx/pytorch:main-py3-devel" ;;
    "torchn")  IMG_LINK="nvcr.io/nvidia/pytorch:26.04-py3" ;;
    *) echo "Unknown image: $IMAGE"; usage ;;
esac

# ── CPU arch ──────────────────────────────────────────────────────────────────
# Match the legacy container-name suffix (arm64 vs x86_64) used by callers.
case "$HOST_ARCH" in
    aarch64) ARCH="arm64" ;;
    *)       ARCH="x86_64" ;;
esac

CONTAINER="te-${IMAGE}-${ARCH}"
CONTAINER_NAME="${CONTAINER}-ct${POSTFIX:+-${POSTFIX}}"

# Per-instance Claude config suffix: image name discriminates sessions running
# different containers; --postfix layers on top for same-image concurrent runs.
# In-container target paths stay the same; only the host source path varies.
CLAUDE_SFX="-${IMAGE}${POSTFIX:+-${POSTFIX}}"

# ── Scratch availability ──────────────────────────────────────────────────────
SCRATCH_OK=false
if [ -d "$SCRATCH" ] && [ -w "$SCRATCH" ]; then
    SCRATCH_OK=true
    mkdir -p "${IMAGE_CACHE_DIR}"
fi

# ── Build/load image ──────────────────────────────────────────────────────────
if [ "$BACKEND" = "docker" ]; then
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
else
    # enroot: pull .sqsh from registry (cached on Lustre).
    # enroot import URL form: docker://[USER@]REGISTRY#PATH:TAG
    SQSH="${IMAGE_CACHE_DIR}/${CONTAINER}.sqsh"
    enroot_url() {
        # ghcr.io/foo/bar:baz -> docker://ghcr.io#foo/bar:baz
        # gitlab-master.nvidia.com/dl/dgx/jax:jax -> docker://gitlab-master.nvidia.com#dl/dgx/jax:jax
        local img="$1"
        local registry="${img%%/*}"
        local rest="${img#*/}"
        echo "docker://${registry}#${rest}"
    }

    if $NO_CACHE; then
        echo "--no-cache: removing cached sqsh (if any)."
        rm -f "$SQSH"
    fi
    if [ ! -f "$SQSH" ]; then
        $SCRATCH_OK || { echo "Error: enroot cache dir ${IMAGE_CACHE_DIR} not writable."; exit 1; }
        echo "Importing image ${IMG_LINK} -> ${SQSH}..."
        enroot import -o "$SQSH" "$(enroot_url "$IMG_LINK")" \
            || { echo "enroot import failed"; exit 1; }
    else
        echo "Using cached sqsh: ${SQSH}"
    fi
    # (Re)create the rootfs container. enroot create is idempotent with --force.
    enroot create --force --name "$CONTAINER_NAME" "$SQSH" \
        || { echo "enroot create failed"; exit 1; }
fi

# ── Mounts (abstract "src:dst" form; backend args built at launch) ────────────
MOUNTS=()

HOME_DIR="/home/phuonguyen"
# Source path → in-container target. On lyris the sources live on Lustre with
# per-arch suffixes (share/claude-<arch>) and the `~/.local/bin/claude` symlink
# is handled separately via CLAUDE_BIN/CLAUDE_MOUNT_TARGET above. On compute-lab
# they're just under $HOME mounted in-place.
case "$MACHINE" in
    lyris)
        # Seed sources on Lustre so the bind-mounts succeed (mirrors launch.sh).
        mkdir -p "${WORKSPACE}/.claude" "${WORKSPACE}/.config" \
                 "${WORKSPACE}/.cache/claude" \
                 "${WORKSPACE}/.local/share/claude-${HOST_ARCH}"
        [ -s "${WORKSPACE}/.claude.json" ] || echo '{}' > "${WORKSPACE}/.claude.json"
        # Per-instance copy, seeded from the base so auth carries over.
        [ -d "${WORKSPACE}/.claude${CLAUDE_SFX}" ] || \
            { mkdir -p "${WORKSPACE}/.claude${CLAUDE_SFX}"; cp -a "${WORKSPACE}/.claude/." "${WORKSPACE}/.claude${CLAUDE_SFX}/" 2>/dev/null || true; }
        [ -f "${WORKSPACE}/.claude${CLAUDE_SFX}.json" ] || cp -p "${WORKSPACE}/.claude.json" "${WORKSPACE}/.claude${CLAUDE_SFX}.json"
        mkdir -p "${WORKSPACE}/.cache/claude${CLAUDE_SFX}"
        CLAUDE_AUTH_MOUNTS=(
            "${WORKSPACE}/.claude${CLAUDE_SFX}:${HOME_DIR}/.claude"
            "${WORKSPACE}/.claude${CLAUDE_SFX}.json:${HOME_DIR}/.claude.json"
        )
        HOME_MOUNTS=(
            "${WORKSPACE}/.local/share/claude-${HOST_ARCH}:${HOME_DIR}/.local/share/claude"
            "${WORKSPACE}/.cache/claude${CLAUDE_SFX}:${HOME_DIR}/.cache/claude"
            "${WORKSPACE}/.config:${HOME_DIR}/.config"
            "${HOME_DIR}/.ssh:${HOME_DIR}/.ssh"
            "${HOME_DIR}/.gitconfig:${HOME_DIR}/.gitconfig"
        )
        ;;
    *)
        # Per-instance copy, seeded from the base so auth carries over.
        [ -d "${HOME_DIR}/.claude${CLAUDE_SFX}" ] || \
            { mkdir -p "${HOME_DIR}/.claude${CLAUDE_SFX}"; cp -a "${HOME_DIR}/.claude/." "${HOME_DIR}/.claude${CLAUDE_SFX}/" 2>/dev/null || true; }
        [ -f "${HOME_DIR}/.claude${CLAUDE_SFX}.json" ] || cp -p "${HOME_DIR}/.claude.json" "${HOME_DIR}/.claude${CLAUDE_SFX}.json" 2>/dev/null || true
        mkdir -p "${HOME_DIR}/.cache/claude${CLAUDE_SFX}"
        CLAUDE_AUTH_MOUNTS=(
            "${HOME_DIR}/.claude${CLAUDE_SFX}:${HOME_DIR}/.claude"
            "${HOME_DIR}/.claude${CLAUDE_SFX}.json:${HOME_DIR}/.claude.json"
        )
        HOME_MOUNTS=(
            "${HOME_DIR}/.local/share/claude:${HOME_DIR}/.local/share/claude"
            "${HOME_DIR}/.local/bin/claude:${HOME_DIR}/.local/bin/claude"
            "${HOME_DIR}/.cache/claude${CLAUDE_SFX}:${HOME_DIR}/.cache/claude"
            "${HOME_DIR}/.config:${HOME_DIR}/.config"
            "${HOME_DIR}/.ssh:${HOME_DIR}/.ssh"
            "${HOME_DIR}/.gitconfig:${HOME_DIR}/.gitconfig"
        )
        ;;
esac

# Mount the per-arch claude binary at the canonical path (set per-machine above)
# so PATH stays the same inside the container.
[ -e "$CLAUDE_BIN" ] && MOUNTS+=("$CLAUDE_BIN:$CLAUDE_MOUNT_TARGET")

# Ensure Claude auth dirs exist on the host.
mkdir -p "${HOME_DIR}/.claude" "${HOME_DIR}/.cache/claude"
touch -a "${HOME_DIR}/.claude.json"

SCRATCH_AUTH_DIR=""   # non-empty when we stage auth through scratch (docker only)
if [ "$BACKEND" = "docker" ]; then
    # Probe whether the Docker daemon can access HOME_DIR subdirs (rootless
    # Docker or restricted home dir permissions may block it).
    HOME_ACCESSIBLE=false
    if docker run --rm -v "${HOME_DIR}/.claude:/tmp/_probe:ro" \
           --entrypoint true "$CONTAINER" 2>/dev/null; then
        HOME_ACCESSIBLE=true
    fi

    if $HOME_ACCESSIBLE; then
        for spec in "${CLAUDE_AUTH_MOUNTS[@]}" "${HOME_MOUNTS[@]}"; do
            [ -e "${spec%%:*}" ] && MOUNTS+=("$spec")
        done
    elif $SCRATCH_OK; then
        # Docker can't reach HOME_DIR. Stage Claude auth in scratch and sync back.
        SCRATCH_AUTH_DIR="${SCRATCH}/.claude-auth${CLAUDE_SFX}"
        mkdir -p "${SCRATCH_AUTH_DIR}/.claude"
        rsync -a "${HOME_DIR}/.claude${CLAUDE_SFX}/" "${SCRATCH_AUTH_DIR}/.claude/" 2>/dev/null || \
            rsync -a "${HOME_DIR}/.claude/" "${SCRATCH_AUTH_DIR}/.claude/" 2>/dev/null || true
        cp -p "${HOME_DIR}/.claude${CLAUDE_SFX}.json" "${SCRATCH_AUTH_DIR}/.claude.json" 2>/dev/null || \
            cp -p "${HOME_DIR}/.claude.json" "${SCRATCH_AUTH_DIR}/.claude.json" 2>/dev/null || true
        echo "Note: home dir not accessible to Docker; staging Claude auth in scratch."
        MOUNTS+=("${SCRATCH_AUTH_DIR}/.claude:${HOME_DIR}/.claude")
        MOUNTS+=("${SCRATCH_AUTH_DIR}/.claude.json:${HOME_DIR}/.claude.json")
        for spec in "${HOME_MOUNTS[@]}"; do
            src="${spec%%:*}"
            if [ -e "$src" ] && \
               docker run --rm -v "$src:/tmp/_probe:ro" --entrypoint true "$CONTAINER" 2>/dev/null; then
                MOUNTS+=("$spec")
            fi
        done
    else
        echo "Warning: Docker daemon cannot access ${HOME_DIR} and scratch is unavailable."
        echo "  Claude will require login. Fix: chmod o+x ${HOME_DIR}"
    fi
else
    # enroot: no daemon, host perms are the user's own — mount auth files directly.
    for spec in "${CLAUDE_AUTH_MOUNTS[@]}" "${HOME_MOUNTS[@]}"; do
        [ -e "${spec%%:*}" ] && MOUNTS+=("$spec")
    done
fi

# Mount scratch at the same path inside the container so absolute paths
# (e.g. git worktrees) stay valid in both directions.
if $SCRATCH_OK; then
    echo "Mounting scratch: ${SCRATCH}"
    MOUNTS+=("${SCRATCH}:${SCRATCH}")
fi

# ── Launch ────────────────────────────────────────────────────────────────────
echo "Launching ${CONTAINER_NAME} [backend=${BACKEND}, image=${IMAGE}, user=${USER_MODE}]..."

# Default workdir = scratch (mounted in-place above) so `pwd` lines up
# host-vs-container.
WORKDIR="$SCRATCH"
INNER_CMD="export PATH=$(dirname "$CLAUDE_MOUNT_TARGET"):\$PATH; cd $WORKDIR; exec bash -i"

if [ "$BACKEND" = "docker" ]; then
    USER_ARGS=()
    if [ "$USER_MODE" = "root" ]; then
        USER_ARGS=(--user root -w "$WORKDIR" -e HOME=/home/phuonguyen)
        echo "Running as: root"
    else
        USER_ARGS=(-w "$WORKDIR" -e HOME=/home/phuonguyen)
        echo "Running as: $(whoami) (non-root, sudo enabled)"
    fi
    DOCKER_MOUNT_ARGS=()
    for m in "${MOUNTS[@]}"; do DOCKER_MOUNT_ARGS+=(-v "$m"); done

    docker rm -f "${CONTAINER_NAME}" &>/dev/null || true
    docker run --gpus all \
        --name "${CONTAINER_NAME}" \
        --rm \
        --ulimit nofile=1000000:1000000 \
        -ti --net=host --ipc=host \
        "${DOCKER_MOUNT_ARGS[@]}" \
        "${USER_ARGS[@]}" \
        --cap-add SYS_PTRACE \
        --security-opt seccomp=unconfined \
        --entrypoint "" \
        "$CONTAINER" bash -c "$INNER_CMD" \
    || { echo "docker failed with exit code $?"; exit 1; }
else
    # enroot start: --rw rw root, --root for root mode. Mounts via --mount.
    ENROOT_ARGS=(--rw)
    [ "$USER_MODE" = "root" ] && ENROOT_ARGS+=(--root)
    ENROOT_ARGS+=(--env "HOME=/home/phuonguyen")
    for m in "${MOUNTS[@]}"; do ENROOT_ARGS+=(--mount "$m"); done

    enroot start "${ENROOT_ARGS[@]}" "$CONTAINER_NAME" bash -c "$INNER_CMD" \
    || { echo "enroot start failed with exit code $?"; exit 1; }
fi

# Sync Claude auth back from scratch to home (if we staged it there).
if [ -n "$SCRATCH_AUTH_DIR" ]; then
    rsync -a "${SCRATCH_AUTH_DIR}/.claude/" "${HOME_DIR}/.claude${CLAUDE_SFX}/" 2>/dev/null || true
    cp -p "${SCRATCH_AUTH_DIR}/.claude.json" "${HOME_DIR}/.claude${CLAUDE_SFX}.json" 2>/dev/null || true
fi
)
