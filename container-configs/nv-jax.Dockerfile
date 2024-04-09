FROM ghcr.io/nvidia/jax:pax
RUN pip install transformers
RUN pip install datasets
RUN pip install accelerate
RUN pip install sentencepiece

# ARG SSH_PRIVATE_KEY
# ARG WORKSPACE

RUN useradd -ms /bin/bash docker
USER docker
WORKDIR /home/docker
RUN export PATH=~/.local/bin:$PATH

#RUN mkdir /root/.ssh/ && echo "${SSH_PRIVATE_KEY}" > /root/.ssh/id_rsa && chmod 600 /root/.ssh/id_rsa
