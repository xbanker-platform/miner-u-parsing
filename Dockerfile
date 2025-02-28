# Use the official Ubuntu base image
FROM nvidia/cuda:11.8.0-cudnn8-runtime-ubuntu22.04

# Set environment variables to non-interactive to avoid prompts during installation
ENV DEBIAN_FRONTEND=noninteractive

# Update the package list and install necessary packages
RUN apt-get update && \
    apt-get install -y \
        software-properties-common && \
    add-apt-repository ppa:deadsnakes/ppa && \
    apt-get update && \
    apt-get install -y \
        python3.10 \
        python3.10-venv \
        python3.10-distutils \
        python3-pip \
        wget \
        git \
        libgl1 \
        libglib2.0-0 \
        && rm -rf /var/lib/apt/lists/*

# Set Python 3.10 as the default python3
RUN update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.10 1

# Create a virtual environment for MinerU
RUN python3 -m venv /opt/mineru_venv

# Activate the virtual environment and install necessary Python packages
RUN /bin/bash -c "source /opt/mineru_venv/bin/activate && \
    pip3 install --upgrade pip && \
    wget https://github.com/opendatalab/MinerU/raw/master/docker/global/requirements.txt -O requirements.txt && \
    pip3 install -r requirements.txt --extra-index-url https://wheels.myhloli.com && \
    pip3 install paddlepaddle-gpu==3.0.0rc1 -i https://www.paddlepaddle.org.cn/packages/stable/cu118/"

# Copy the configuration file template and install magic-pdf latest
RUN /bin/bash -c "wget https://github.com/opendatalab/MinerU/raw/master/magic-pdf.template.json && \
    cp magic-pdf.template.json /root/magic-pdf.json && \
    source /opt/mineru_venv/bin/activate && \
    pip3 install -U magic-pdf"

# Download models and update the configuration file
RUN /bin/bash -c "pip3 install huggingface_hub && \
    wget https://github.com/opendatalab/MinerU/raw/master/scripts/download_models_hf.py -O download_models.py && \
    python3 download_models.py && \
    sed -i 's|cpu|cuda|g' /root/magic-pdf.json"

# Install FastAPI and related dependencies
RUN /bin/bash -c "source /opt/mineru_venv/bin/activate && \
    pip3 install fastapi==0.104.1 uvicorn==0.23.2 python-multipart==0.0.6 pydantic==2.4.2"

# Install support for CUDA PyTorch
RUN pip install --force-reinstall torch==2.3.1 torchvision==0.18.1 --index-url https://download.pytorch.org/whl/cu118

# Install support for CUDA PaddlePaddle (for OCR acceleration)
RUN pip install paddlepaddle-gpu==2.6.1

# Download model files
RUN pip install huggingface_hub && \
    wget https://github.com/opendatalab/MinerU/raw/master/scripts/download_models_hf.py -O /tmp/download_models_hf.py && \
    python /tmp/download_models_hf.py && \
    mkdir -p /app/models && \
    cp -r ~/magic-pdf-models/* /app/models/

# Set the entry point to activate the virtual environment and run the command line tool
ENTRYPOINT ["/bin/bash", "-c", "source /opt/mineru_venv/bin/activate && exec \"$@\"", "--"]