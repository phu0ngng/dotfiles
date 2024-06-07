#/bin/bash

srun -A coreai_dlfw_dev -N1 -p batch\
    -t 4:00:00 -J coreai_dlfw_dev-te:te_jax\
    --container-image=ghcr.io/nvidia/jax:pax\
    --container-name=jax-ct\
    --container-mounts /home/phuonguyen/te-jax\
    --container-workdir=/home/phuonguyen/te-jax\
    --no-container-remap-root --pty bash
