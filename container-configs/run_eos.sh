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
    IMAGE_LINK="gitlab-master.nvidia.com/dl/dgx/pytorch:master-py3-devel"
    ;;
  "bw-jax")
    IMAGE_LINK="gitlab-master.nvidia.com:5005/dl/dgx/jax:blackwell-jax"
    ;;
  "bw-torch")
    IMAGE_LINK="gitlab-master.nvidia.com/dl/dgx/pytorch:blackwell-py3-devel"
    ;;
  *)
    echo "Invalid IMAGE"
    ;;
esac

srun -A coreai_dlfw_dev -N1 -p batch\
    -t 4:00:00 -J coreai_dlfw_dev-te:te_jax\
    --container-image=${IMAGE_LINK}\
    --container-name=${IMAGE}-ct\
    --container-mounts "/home/phuonguyen/te-${TE}"\
    --container-workdir="/home/phuonguyen/te-${TE}"\
    --no-container-remap-root --pty bash
