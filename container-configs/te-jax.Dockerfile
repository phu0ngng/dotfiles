FROM ghcr.io/nvidia/jax:jax
RUN pip install pybind11 ninja
# RUN apt-get update
# RUN apt-get install time -y

ARG NEW_USER
ARG NEW_UID
ARG NEW_GID
 
RUN useradd ${NEW_USER} -s /bin/bash -u${NEW_UID} -g${NEW_GID} -d/home/${NEW_USER}
USER ${NEW_USER}

WORKDIR /home/${NEW_USER}
ENV PATH="~/.local/bin:$PATH"
