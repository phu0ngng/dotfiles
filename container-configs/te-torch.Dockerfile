FROM gitlab-master.nvidia.com/dl/dgx/pytorch:master-py3-devel
RUN pip install transformers
RUN pip install datasets
RUN pip install accelerate
RUN pip install sentencepiece

WORKDIR /te
