ARG IMAGE
 
FROM ${IMAGE} 
RUN pip install pybind11 pytest ninja
RUN apt-get update -y
RUN apt-get install sudo -y
RUN apt-get install gdb python3-dbg -y

ARG NEW_USER
ARG NEW_UID
ARG NEW_GID
RUN groupadd -g ${NEW_GID} ${NEW_USER}
RUN useradd -m -g${NEW_GID} ${NEW_USER} -u${NEW_UID} -d/home/${NEW_USER} -s /bin/bash
RUN usermod -aG sudo ${NEW_USER}
RUN echo "%sudo ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

USER ${NEW_USER}

WORKDIR /home/${NEW_USER}
ENV PATH="~/.local/bin:$PATH"
ENV LD_LIBRARY_PATH="/home/${NEW_USER}/cudnn/lib64:$LD_LIBRARY_PATH"
ENV NVTE_BUILD_THREADS_PER_JOB=2
