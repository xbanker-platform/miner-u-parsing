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

# Activate the virtual environment and install necessary Python packages
RUN /bin/bash -c "source /opt/mineru_venv/bin/activate && \
    pip3 install --upgrade pip && \
    pip3 install --no-cache-dir -r /requirements.txt --extra-index-url https://wheels.myhloli.com && \
    pip3 install --no-cache-dir paddlepaddle-gpu==3.0.0b1 -i https://www.paddlepaddle.org.cn/packages/stable/cu118/"

# Create a working directory
WORKDIR /app

# Copy application code
COPY app /app
COPY scripts /app/scripts

# Create necessary directories
RUN mkdir -p /models /output /uploads /data

# Download model files
COPY scripts/download_models_hf.py /app/download_models_hf.py
RUN /bin/bash -c "source /opt/mineru_venv/bin/activate && python3 /app/download_models_hf.py"

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

# Expose port
EXPOSE 8000

# Set the entry point to activate the virtual environment and run the command line tool
ENTRYPOINT ["/bin/bash", "-c", "source /opt/mineru_venv/bin/activate && exec \"$@\"", "--"]

# Start command
CMD ["uvicorn", "app:app", "--host", "0.0.0.0", "--port", "8000"]