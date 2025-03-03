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

# Copy application code
COPY app /app
COPY scripts /app/scripts

# Create necessary directories
RUN mkdir -p /models /output /uploads /data

# Copy and run the download script
COPY scripts/download_models_hf_modified.py /app/download_models_hf_modified.py
RUN /bin/bash -c "source /opt/mineru_venv/bin/activate && python3 /app/download_models_hf_modified.py"

# Create configuration file (if download script fails, ensure config file exists)
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

# 复制配置文件到用户目录
RUN cp /app/magic-pdf.json /root/magic-pdf.json

# 创建启动脚本
RUN echo '#!/bin/bash\n\
\n\
# 确保配置文件存在\n\
if [ ! -f "/app/magic-pdf.json" ]; then\n\
    echo "配置文件不存在，创建默认配置..."\n\
    echo '"'"'{\n\
        "bucket_info":{},\n\
        "models-dir":"/models",\n\
        "layoutreader-model-dir":"/models/layoutreader",\n\
        "device-mode":"cuda",\n\
        "layout-config": {\n\
            "model": "layoutlmv3"\n\
        },\n\
        "formula-config": {\n\
            "mfd_model": "yolo_v8_mfd",\n\
            "mfr_model": "unimernet_small",\n\
            "enable": true\n\
        },\n\
        "table-config": {\n\
            "model": "rapid_table",\n\
            "enable": true,\n\
            "max_time": 400\n\
        },\n\
        "config_version": "1.0.0"\n\
    }'"'"' > /app/magic-pdf.json\n\
    \n\
    # 同时复制到用户目录\n\
    cp /app/magic-pdf.json /root/magic-pdf.json\n\
fi\n\
\n\
# 设置环境变量\n\
export MINERU_TOOLS_CONFIG_JSON=/app/magic-pdf.json\n\
\n\
# 启动应用\n\
exec uvicorn app:app --host 0.0.0.0 --port 8000\n\
' > /app/start_app.sh
RUN chmod +x /app/start_app.sh

# Expose port
EXPOSE 8000

# Set the entry point to activate the virtual environment and run the command line tool
ENTRYPOINT ["/bin/bash", "-c", "source /opt/mineru_venv/bin/activate && exec \"$@\"", "--"]

# Start command
CMD ["/app/start_app.sh"]