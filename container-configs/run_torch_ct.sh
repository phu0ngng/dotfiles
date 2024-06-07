#/bin/bash

srun -A coreai_dlfw_dev -N1 -p batch\
    -t 4:00:00 -J coreai_dlfw_dev-te:te_jax\
    --container-image=gitlab-master.nvidia.com/dl/dgx/pytorch:master-py3-devel\
    --container-name=torch-ct\
    --container-mounts "/home/phuonguyen/te-torch"\
    --container-workdir="/home/phuonguyen/te-torch"\
    --no-container-remap-root --pty bash
    # --container-mounts "/home/phuonguyen/te-torch:/opt/te-torch,/lustre/fsw/coreai_dlfw_dev/ksivamani/fp8/data:/opt/te-data,/home/phuonguyen/megatron-lm:/opt/megatron-lm"\
    # --container-image=gitlab-master.nvidia.com/adlr/megatron-lm/pytorch:24.01-py3-draco_cw_ub_tot-te\
