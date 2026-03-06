#/bin/bash

if [ -z "${IMAGE}" ]; then
  IMAGE="jax"
fi

if [ -z "${TE}" ]; then
  TE="${IMAGE}"
fi

case "$IMAGE" in
  "jax")
    IMAGE_LINK="ghcr.io/nvidia/jax:jax"
    ;;
  "torch")
    IMAGE_LINK="gitlab-master.nvidia.com/dl/dgx/pytorch:main-py3-devel"
    ;;
  "bw-jax")
    IMAGE_LINK="gitlab-master.nvidia.com/dl/dgx/jax:jax"
    ;;
  "bw-torch")
    IMAGE_LINK="gitlab-master.nvidia.com/dl/dgx/pytorch:main-py3-devel"
    ;;
  *)
    echo "Invalid IMAGE"
    ;;
esac

ENV_VARS="PATH='~/.local/bin:\$PATH',NVTE_BUILD_THREADS_PER_JOB=4"

SAVED_IMAGE=`pwd`/images/${IMAGE}.sqsh
mkdir -p "`pwd`/images"

PARTITION="batch"
ACCOUNT="coreai_dlfw_dev"

# If SAVED_IMAGE doesn't exist, fetch a new image from the IMAGE_LINK
if [ -f "$SAVED_IMAGE" ]; then
  IMAGE_LINK="$SAVED_IMAGE"
fi

srun -A $ACCOUNT -N 1 -p $PARTITION -t 4:00:00 \
  -J "$ACCOUNT-te.test-${IMAGE}" \
  --container-image=${IMAGE_LINK} \
  --container-name=${IMAGE}-ct \
  --container-save="${SAVED_IMAGE}" \
  --container-mounts "${WORKSPACE}/te":"/home/phuonguyen/te" \
  --container-workdir="/home/phuonguyen/te" \
  --export=$ENV_VARS \
  --no-container-remap-root \
  --pty bash
