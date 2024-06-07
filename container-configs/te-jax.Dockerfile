FROM ghcr.io/nvidia/jax:pax
# FROM gitlab-master.nvidia.com/dl/dgx/jax:blackwell-devel
RUN pip install transformers
RUN pip install datasets
RUN pip install accelerate
RUN pip install sentencepiece

ARG NEW_USER
ARG NEW_UID
ARG NEW_GID
 
# RUN useradd ${NEW_USER} -s /bin/bash -u${NEW_UID} -g${NEW_GID} -d/home/${NEW_USER}
# USER ${NEW_USER}
#
# WORKDIR /home/${NEW_USER}
# RUN export PATH=~/.local/bin:$PATH
