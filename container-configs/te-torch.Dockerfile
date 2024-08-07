FROM gitlab-master.nvidia.com/dl/dgx/pytorch:master-py3-devel
# FROM nvcr.io/nvidia/pytorch:24.05-py3
RUN pip install pybind11 ninja

ARG NEW_USER
ARG NEW_UID
ARG NEW_GID
 
RUN useradd ${NEW_USER} -s /bin/bash -u${NEW_UID} -g${NEW_GID} -d/home/${NEW_USER}
USER ${NEW_USER}

WORKDIR /home/${NEW_USER}
ENV PATH="~/.local/bin:$PATH"
