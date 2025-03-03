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

# 在安装其他包之前，先安装正确版本的NumPy和OpenCV
RUN /bin/bash -c "source /opt/mineru_venv/bin/activate && \
    pip uninstall -y numpy opencv-python paddle paddlepaddle-gpu && \
    pip install numpy==1.24.3 && \
    pip install opencv-python==4.8.0.74"

# Install support for CUDA PyTorch
RUN /bin/bash -c "source /opt/mineru_venv/bin/activate && \
    pip install --force-reinstall torch==2.3.1 torchvision==0.18.1 --index-url https://download.pytorch.org/whl/cu118"

# Install support for CUDA PaddlePaddle (for OCR acceleration)
RUN /bin/bash -c "source /opt/mineru_venv/bin/activate && \
    pip install paddlepaddle-gpu==3.0.0b1 -i https://www.paddlepaddle.org.cn/packages/stable/cu118/"

# 重新安装magic-pdf以确保它使用正确的依赖
RUN /bin/bash -c "source /opt/mineru_venv/bin/activate && \
    pip uninstall -y magic-pdf && \
    pip install -U magic-pdf"

# Download model files
RUN /bin/bash -c "source /opt/mineru_venv/bin/activate && \
    pip install huggingface_hub && \
    wget https://github.com/opendatalab/MinerU/raw/master/scripts/download_models_hf.py -O /tmp/download_models_hf.py && \
    python3 /tmp/download_models_hf.py && \
    mkdir -p /app/models/MFD/YOLO && \
    mkdir -p /app/models/MFR && \
    mkdir -p /app/models/layout && \
    mkdir -p /app/models/layoutreader && \
    cp -r /root/.cache/huggingface/hub/models--opendatalab--PDF-Extract-Kit-1.0/snapshots/*/models/* /app/models/ && \
    find /root/.cache/huggingface/hub/models--opendatalab--PDF-Extract-Kit-1.0 -name 'yolo_v8_mfd.pt' -exec cp {} /app/models/MFD/YOLO/ \; && \
    find /root/.cache/huggingface/hub/models--opendatalab--PDF-Extract-Kit-1.0 -name 'unimernet_small.onnx' -exec cp {} /app/models/MFR/ \; && \
    find /root/.cache/huggingface/hub/models--opendatalab--PDF-Extract-Kit-1.0 -name 'doclayout_yolo.pt' -exec cp {} /app/models/layout/ \; && \
    cp -r /root/.cache/huggingface/hub/models--hantian--layoutreader/snapshots/*/* /app/models/layoutreader/ && \
    ls -R /app/models"

# 创建工作目录
WORKDIR /app

# 复制所有脚本和配置文件
COPY scripts/ /app/scripts/
COPY tests/ /app/tests/
COPY nginx.conf /etc/nginx/conf.d/default.conf

# 设置脚本权限
RUN chmod +x /app/scripts/*.sh

# 复制自定义配置文件
COPY magic-pdf.json /root/magic-pdf.json



# 设置入口点
ENTRYPOINT ["/app/scripts/entrypoint.sh"]