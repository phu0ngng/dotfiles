#!/bin/bash

#srun -p DGX1V_16G -t 8:00:00 --pty /bin/bash

# set -x
CONTAINER="nv-jax"
CONTAINER_NAME="jax-ct"
if [ $# -ne 0 ]
then
	echo $1
	CONTAINER=$1
fi
echo $CONTAINER


# Mounts
BASE_DIR="/mnt/nvdl/usr/phuonguyen/te-jax"
KEY_PATH="/home/phuonguyen/.ssh"


docker build -t $CONTAINER -f ${CONTAINER}.Dockerfile .


nvidia-docker run --name ${CONTAINER_NAME} \
  -ti --net=host  --ipc=host \
  -v "${BASE_DIR}":"/home/docker/te-jax"  \
  --entrypoint bash \
  --privileged $CONTAINER
set +x
