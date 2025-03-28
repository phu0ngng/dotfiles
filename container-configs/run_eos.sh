#/bin/bash
#
# TE_MNT="/home/phuonguyen/te-jax:/home/phuonguyen/te-jax"
# DATA_MNT="/lustre/fsw/coreai_dlfw_dev/mingh:/opt/llama"

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
    IMAGE_LINK="gitlab-master.nvidia.com:5005/dl/dgx/jax:jax"
    ;;
  "bw-torch")
    IMAGE_LINK="gitlab-master.nvidia.com/dl/dgx/pytorch:main-py3-devel"
    ;;
  *)
    echo "Invalid IMAGE"
    ;;
esac


SAVED_IMAGE=`pwd`/images/${IMAGE}.sqsh

mkdir -p "`pwd`/images"

PARTITION="batch"
ACCOUNT="coreai_dlfw_dev"

if [ -f "$SAVED_IMAGE" ]; then
  srun -A $ACCOUNT -N 1 -p $PARTITION -t 4:00:00 \
    -J "$ACCOUNT-te.test-${IMAGE}" \
    --container-image=${SAVED_IMAGE} \
    --container-name=${IMAGE}-ct \
    --container-mounts "${WORKSPACE}/te-${TE}":"/home/phuonguyen/te-${TE}" \
    --container-workdir="/home/phuonguyen/te-${TE}" \
    --no-container-remap-root --pty bash
else
  # If SAVED_IMAGE doesn't exist, fetch a new image from the IMAGE_LINK
  srun -A $ACCOUNT -N 1 -p $PARTITION -t 4:00:00 \
    -J "$ACCOUNT-te.test-${IMAGE}" \
    --container-image=${IMAGE_LINK} \
    --container-name=${IMAGE}-ct \
    --container-save="${SAVED_IMAGE}" \
    --container-mounts "${WORKSPACE}/te-${TE}":"/home/phuonguyen/te-${TE}" \
    --container-workdir="/home/phuonguyen/te-${TE}" \
    --no-container-remap-root --pty bash
fi
