FROM gitlab-master.nvidia.com:5005/dl/dgx/jax:blackwell-jax-2024-07-30
RUN pip install pybind11 pytest ninja
# RUN apt-get update -y
# RUN apt-get install gdb -y
# RUN apt-get install python3-dbg -y

ARG NEW_USER
ARG NEW_UID
ARG NEW_GID
 
RUN useradd ${NEW_USER} -s /bin/bash -u${NEW_UID} -g${NEW_GID} -d/home/${NEW_USER}
USER ${NEW_USER}

WORKDIR /home/${NEW_USER}
ENV PATH="~/.local/bin:$PATH"
