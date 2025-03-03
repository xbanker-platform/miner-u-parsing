# Use the official Ubuntu base image
FROM nvidia/cuda:12.1.0-base-ubuntu22.04

# Set environment variables to non-interactive to avoid prompts during installation
ENV DEBIAN_FRONTEND=noninteractive

# Update the package list and install necessary packages
RUN apt-get update && \
    apt-get install -y \
        python3 \
        python3-pip \
        python3-venv \
        wget \
        libreoffice \
        git \
        && apt-get clean \
        && rm -rf /var/lib/apt/lists/*

# Create a virtual environment for MinerU
RUN python3 -m venv /opt/mineru_venv

# Create requirements.txt file
RUN echo "magic-pdf[full]" > /requirements.txt
RUN echo "huggingface_hub" >> /requirements.txt
RUN echo "fastapi" >> /requirements.txt
RUN echo "uvicorn" >> /requirements.txt
RUN echo "python-multipart" >> /requirements.txt
RUN echo "paddlepaddle-gpu==2.5.2" >> /requirements.txt

# Activate the virtual environment and install necessary Python packages
RUN /bin/bash -c "source /opt/mineru_venv/bin/activate && \
    pip3 install --upgrade pip && \
    pip3 install --no-cache-dir -r /requirements.txt --extra-index-url https://wheels.myhloli.com"

# Create a working directory
WORKDIR /app

# Copy application code
COPY app /app
COPY scripts /app/scripts

# Create necessary directories
RUN mkdir -p /models /output /uploads /data

# 创建修改后的下载脚本
RUN echo '
import os
import json
from huggingface_hub import snapshot_download
import requests

# 增加超时时间
requests.adapters.DEFAULT_TIMEOUT = 300  # 设置为5分钟

# 设置模型目录
models_dir = "/models"
layoutreader_dir = os.path.join(models_dir, "layoutreader")

# 创建目录
os.makedirs(models_dir, exist_ok=True)
os.makedirs(layoutreader_dir, exist_ok=True)

# 下载模型
print("开始下载模型...")

try:
    # 下载 layoutlmv3 模型
    print("下载 layoutlmv3 模型...")
    snapshot_download(
        repo_id="opendatalab/layoutlmv3-base-chinese", 
        local_dir=os.path.join(models_dir, "layoutlmv3-base-chinese"),
        local_dir_use_symlinks=False,
        revision="main"
    )
    
    # 下载 layoutreader 模型
    print("下载 layoutreader 模型...")
    snapshot_download(
        repo_id="opendatalab/layoutreader", 
        local_dir=layoutreader_dir,
        local_dir_use_symlinks=False,
        revision="main"
    )
    
    # 下载 formula 模型
    print("下载 formula 模型...")
    snapshot_download(
        repo_id="opendatalab/yolo_v8_mfd", 
        local_dir=os.path.join(models_dir, "yolo_v8_mfd"),
        local_dir_use_symlinks=False,
        revision="main"
    )
    snapshot_download(
        repo_id="opendatalab/unimernet_small", 
        local_dir=os.path.join(models_dir, "unimernet_small"),
        local_dir_use_symlinks=False,
        revision="main"
    )
    
    # 下载 table 模型
    print("下载 table 模型...")
    snapshot_download(
        repo_id="opendatalab/rapid_table", 
        local_dir=os.path.join(models_dir, "rapid_table"),
        local_dir_use_symlinks=False,
        revision="main"
    )
    
    print("所有模型下载完成！")
    
except Exception as e:
    print(f"下载模型时出错: {str(e)}")
    # 继续执行，不要因为下载失败而中断构建过程
    pass

# 创建配置文件
config = {
    "bucket_info": {},
    "models-dir": models_dir,
    "layoutreader-model-dir": layoutreader_dir,
    "device-mode": "cuda",
    "layout-config": {
        "model": "layoutlmv3"
    },
    "formula-config": {
        "mfd_model": "yolo_v8_mfd",
        "mfr_model": "unimernet_small",
        "enable": True
    },
    "table-config": {
        "model": "rapid_table",
        "enable": True,
        "max_time": 400
    },
    "config_version": "1.0.0"
}

# 保存配置文件
with open("/app/magic-pdf.json", "w") as f:
    json.dump(config, f, indent=4)

print("配置文件已创建")
' > /app/download_models_hf_modified.py

# 运行修改后的下载脚本
RUN /bin/bash -c "source /opt/mineru_venv/bin/activate && python3 /app/download_models_hf_modified.py"

# 创建配置文件（如果下载脚本失败，确保配置文件存在）
RUN echo '{\
    "bucket_info":{},\
    "models-dir":"/models",\
    "layoutreader-model-dir":"/models/layoutreader",\
    "device-mode":"cuda",\
    "layout-config": {\
        "model": "layoutlmv3"\
    },\
    "formula-config": {\
        "mfd_model": "yolo_v8_mfd",\
        "mfr_model": "unimernet_small",\
        "enable": true\
    },\
    "table-config": {\
        "model": "rapid_table",\
        "enable": true,\
        "max_time": 400\
    },\
    "config_version": "1.0.0"\
}' > /app/magic-pdf.json

# Expose port
EXPOSE 8000

# Set the entry point to activate the virtual environment and run the command line tool
ENTRYPOINT ["/bin/bash", "-c", "source /opt/mineru_venv/bin/activate && exec \"$@\"", "--"]

# Start command
CMD ["uvicorn", "app:app", "--host", "0.0.0.0", "--port", "8000"]