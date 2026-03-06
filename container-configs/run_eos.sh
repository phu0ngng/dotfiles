#!/bin/bash

srun -A coreai_dlfw_dev -N1 -p batch\
    -t 4:00:00 -J coreai_dlfw_dev-te:te_maxtext\
    --container-image="ghcr.io/nvidia/jax:maxtext-2026-03-05"\
    --container-name=te_ct\
    --container-mounts "/lustre/fsw/coreai_dlfw_dev/phuong:/scratch,/home/phuonguyen/te,/home/phuonguyen/.local/share/claude,/home/phuonguyen/.local/bin/claude,/home/phuonguyen/.claude,/home/phuonguyen/.claude.json,/home/phuonguyen/.config,/home/phuonguyen/.cache/claude,/home/phuonguyen/maxtext,/home/phuonguyen/.ssh,/home/phuonguyen/te"\
    --container-workdir="/home/phuonguyen/te"\
    --container-writable \
    --no-container-remap-root\
    --export=ALL \
    --pty bash -c 'export HOME=/home/phuonguyen && export PATH=/home/phuonguyen/.local/bin:$PATH && apt-get update && apt-get install -y bubblewrap socat && pip install ninja pybind11 pytest && exec bash --rcfile <(echo "export HOME=/home/phuonguyen; export PATH=/home/phuonguyen/.local/bin:\$PATH; alias teinstall=\"pip install --no-build-isolation -e .\"")'
