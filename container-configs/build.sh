#!/bin/bash

if [ -z "${FRAMEWORK}" ]; then 
  FRAMEWORK="jax"
fi

CONTAINER="te-${FRAMEWORK}"
CONTAINER_NAME="${CONTAINER}-container"

BASE_DIR="${WORKSPACE}/te-${FRAMEWORK}"

docker build \
  --build-arg NEW_USER=$(whoami)\
  --build-arg NEW_UID=$(id -u)\
  --build-arg NEW_GID=$(id -g)\
  -t $CONTAINER \
  -f ${CONTAINER}.Dockerfile .

nvidia-docker run --name ${CONTAINER_NAME} \
  -ti --net=host  --ipc=host \
  -v "${BASE_DIR}":"/home/$(whoami)/te"  \
  --entrypoint bash \
  --privileged $CONTAINER 
  
set +x
