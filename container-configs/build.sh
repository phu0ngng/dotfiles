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
    IMAGE_LINK="ghcr.io/nvidia/jax:pax"
    ;;
  "bw-jax")
    IMAGE_LINK="gitlab-master.nvidia.com:5005/dl/dgx/jax:blackwell-jax-upstream"
    ;;
  "torch")
    IMAGE_LINK="gitlab-master.nvidia.com:5005/dl/dgx/pytorch:main-py3-devel"
    ;;
  "bw-torch")
    IMAGE_LINK="gitlab-master.nvidia.com:5005/dl/dgx/pytorch:main-py3-devel"
    ;;
  *)
    echo "Invalid IMAGE"
    ;;
esac

CUDNN_NON_BW="debug_cudnn-linux-x86_64-9.7.0.21"
CUDNN_BW="debug_cudnn-linux-x86_64-9.99.3.27"

case "$IMAGE" in
  "bw-jax")
    CUDNN=$CUDNN_BW
    ;;
  "bw-torch")
    CUDNN=$CUDNN_BW
    ;;
  *)
    CUDNN=$CUDNN_NON_BW
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
  -v "${WORKSPACE}/${CUDNN}/debug_cudnn":"/home/$(whoami)/cudnn" \
  -v "${WORKSPACE}/cublas-x86_64-redhat8-cuda12.7_r565":"/home/$(whoami)/cublas" \
  -v "${WORKSPACE}/jax":"/home/$(whoami)/jax" \
  -v "${WORKSPACE}/scc":"/home/$(whoami)/scc" \
  --entrypoint bash \
  --privileged $CONTAINER 
  
set +x
