#!/bin/bash

if [ -z "${IMAGE}" ]; then 
  IMAGE="jax"
fi

if [ -z "${TE}" ]; then 
  TE="${IMAGE}"
fi

CONTAINER="te-${IMAGE}"
CONTAINER_NAME="${CONTAINER}-ct"

BASE_DIR="${WORKSPACE}/te-${TE}"

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

case "$IMAGE" in
  "bw-jax")
    CUDNN="cudnn-bw"
    ;;
  "bw-torch")
    CUDNN="cudnn-bw"
    ;;
  *)
    CUDNN="cudnn"
    ;;
esac

docker build \
  --build-arg NEW_USER=$(whoami)\
  --build-arg NEW_UID=$(id -u)\
  --build-arg NEW_GID=$(id -g)\
  --build-arg IMAGE=${IMAGE_LINK}\
  -t $CONTAINER \
  -f te.Dockerfile .

nvidia-docker run --name ${CONTAINER_NAME} \
   --ulimit nofile=1000000:1000000 \
  -ti --net=host  --ipc=host \
  -v "${BASE_DIR}":"/home/$(whoami)/te" \
  -v "${WORKSPACE}/${CUDNN}":"/home/$(whoami)/cudnn" \
  -v "${WORKSPACE}/cublas":"/home/$(whoami)/cublas" \
  --entrypoint bash \
  --privileged $CONTAINER 
  
set +x
