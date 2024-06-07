#/bin/bash

TE_MNT="/home/phuonguyen/te-jax:/home/phuonguyen/te-jax"
# DATA_MNT="/lustre/share/coreai_dlalgo_ci/artifacts/model/llama2_7b_jax/ckpt_fw-pax/24.02.0_bf16:/mnt/LLaMA7B_checkpoint_0_te_0/checkpoints/checkpoint_00000000:ro"
# DATA_MNT="$DATA_MNT,/lustre/share/coreai_dlalgo_ci/artifacts/model/llama2_7b_jax/ckpt_fw-pax/24.03.0-te_bf16:/mnt/LLaMA7B_checkpoint_0_te_1/checkpoints/checkpoint_00000000:ro"
# DATA_MNT="$DATA_MNT,/lustre/share/coreai_dlalgo_ci/artifacts/model/sentencepiece_llama/tokenizer/23.07.0:/mnt/vocab_llama:ro"
DATA_MNT="/lustre/fsw/coreai_dlfw_dev/mingh:/opt/llama"

srun -A coreai_dlfw_dev -N1 -p batch\
  -t 4:00:00 -J coreai_dlfw_dev-te:te_jax\
  --container-image gitlab-master.nvidia.com/dl/jet/ci/paxml-rosetta:main_15474349\
  --container-name=paxml-ct\
  --container-mounts $TE_MNT,$DATA_MNT\
  --no-container-remap-root\
  --no-container-mount-home\
  --pty bash

  #--container-image ghcr.io/nvidia/jax:pax\
    #--label bash -c 'cd /jet && bash workloads/recipe/paxml_llama7b_paxml-rosetta_converge-llama-boolq_platforms--dgxa100-dgxh100-_bfloat16_nodes-1_gpus-8_bs-2_ici--1-8-1-_lora-1_te-0/common/batch_setup.sh'

