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
    pip3 install -r requirements.txt --extra-index-url https://wheels.myhloli.com"

# Install FastAPI and related dependencies
RUN /bin/bash -c "source /opt/mineru_venv/bin/activate && \
    pip3 install fastapi==0.104.1 uvicorn==0.23.2 python-multipart==0.0.6 pydantic==2.4.2"

# Install correct versions of NumPy and OpenCV first
RUN /bin/bash -c "source /opt/mineru_venv/bin/activate && \
    pip uninstall -y numpy opencv-python paddle paddlepaddle-gpu && \
    pip install numpy==1.24.3 && \
    pip install opencv-python==4.8.0.74"

# Install support for CUDA PyTorch
RUN /bin/bash -c "source /opt/mineru_venv/bin/activate && \
    pip install --force-reinstall torch==2.3.1 torchvision==0.18.1 --index-url https://download.pytorch.org/whl/cu118"

# 尝试安装CPU版本的PaddlePaddle
RUN /bin/bash -c "source /opt/mineru_venv/bin/activate && \
    pip install paddlepaddle==2.5.2 || \
    echo 'Failed to install PaddlePaddle, OCR functionality may be limited'"

# Install magic-pdf
RUN /bin/bash -c "source /opt/mineru_venv/bin/activate && \
    pip install -U magic-pdf"

# Create a working directory
WORKDIR /app

# Copy all scripts and configuration files
COPY scripts/ /app/scripts/
COPY tests/ /app/tests/
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY magic-pdf.json /root/magic-pdf.json

# Set script permissions
RUN chmod +x /app/scripts/*.sh

# Set entry point
ENTRYPOINT ["/app/scripts/entrypoint.sh"]

# Set default command
CMD ["python", "-m", "uvicorn", "app:app", "--host", "0.0.0.0", "--port", "8000", "--workers", "1"]