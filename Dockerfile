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
        curl \
        libreoffice \
        git \
        ccache \
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

# Create necessary directories
RUN mkdir -p /models/MFD/YOLO /models/layoutlmv3-base-chinese /models/layoutreader /models/rapid_table /models/unimernet_small /models/yolo_v8_mfd
RUN mkdir -p /output /uploads /data

# 下载模型文件
RUN wget -q --show-progress https://github.com/opendatalab/MinerU/raw/master/scripts/download_models_hf.py -O /app/download_models_hf.py && \
    /bin/bash -c "source /opt/mineru_venv/bin/activate && python3 /app/download_models_hf.py"

# 直接下载 yolo_v8_ft.pt 模型
RUN wget -q --show-progress https://huggingface.co/opendatalab/yolo_v8_mfd/resolve/main/yolo_v8_ft.pt -O /models/MFD/YOLO/yolo_v8_ft.pt || \
    curl -L https://huggingface.co/opendatalab/yolo_v8_mfd/resolve/main/yolo_v8_ft.pt -o /models/MFD/YOLO/yolo_v8_ft.pt

# Create configuration file
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

# 复制配置文件到多个位置
RUN cp /app/magic-pdf.json /root/magic-pdf.json && \
    mkdir -p /home/root && \
    cp /app/magic-pdf.json /home/root/magic-pdf.json

# 设置环境变量
ENV MINERU_TOOLS_CONFIG_JSON=/app/magic-pdf.json

# Copy application code
COPY app /app
COPY scripts /app/scripts

# 创建启动脚本
COPY app/start_app.sh /app/start_app.sh
RUN chmod +x /app/start_app.sh /app/scripts/download_models.sh

# Expose port
EXPOSE 8000

# Set the entry point to activate the virtual environment and run the command line tool
ENTRYPOINT ["/bin/bash", "-c", "source /opt/mineru_venv/bin/activate && exec \"$@\"", "--"]

# Start command
CMD ["/app/start_app.sh"]