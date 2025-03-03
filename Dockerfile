# 使用NVIDIA官方CUDA镜像
FROM nvidia/cuda:11.8.0-cudnn8-runtime-ubuntu22.04

# 设置环境变量为非交互式，避免安装过程中的提示
ENV DEBIAN_FRONTEND=noninteractive

# 更新包列表并安装必要的包
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

# 将Python 3.10设置为默认的python3
RUN update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.10 1

# 为MinerU创建虚拟环境
RUN python3 -m venv /opt/mineru_venv

# 激活虚拟环境并安装必要的Python包
RUN /bin/bash -c "source /opt/mineru_venv/bin/activate && \
    pip3 install --upgrade pip && \
    wget https://github.com/opendatalab/MinerU/raw/master/docker/global/requirements.txt -O requirements.txt && \
    pip3 install -r requirements.txt --extra-index-url https://wheels.myhloli.com"

# 安装FastAPI和相关依赖
RUN /bin/bash -c "source /opt/mineru_venv/bin/activate && \
    pip3 install fastapi==0.104.1 uvicorn==0.23.2 python-multipart==0.0.6 pydantic==2.4.2"

# 在安装其他包之前，先安装正确版本的NumPy和OpenCV
RUN /bin/bash -c "source /opt/mineru_venv/bin/activate && \
    pip uninstall -y numpy opencv-python paddle paddlepaddle-gpu && \
    pip install numpy==1.24.3 && \
    pip install opencv-python==4.8.0.74"

# 安装支持CUDA的PyTorch
RUN /bin/bash -c "source /opt/mineru_venv/bin/activate && \
    pip install --force-reinstall torch==2.3.1 torchvision==0.18.1 --index-url https://download.pytorch.org/whl/cu118"

# 尝试安装CPU版本的PaddlePaddle
RUN /bin/bash -c "source /opt/mineru_venv/bin/activate && \
    pip install paddlepaddle==2.5.2 || \
    echo 'Failed to install PaddlePaddle, OCR functionality may be limited'"

# 安装magic-pdf
RUN /bin/bash -c "source /opt/mineru_venv/bin/activate && \
    pip install -U magic-pdf"

# 创建工作目录
WORKDIR /app

# 复制所有脚本和配置文件
COPY scripts/ /app/scripts/
COPY tests/ /app/tests/
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY magic-pdf.json /root/magic-pdf.json

# 设置脚本权限（确保使用chmod +x）
RUN chmod +x /app/scripts/*.sh

# 直接使用CMD而不是ENTRYPOINT
CMD ["/bin/bash", "-c", "source /opt/mineru_venv/bin/activate && \
     # 清理缓存 \
     rm -rf /root/.cache/pip/* || true && \
     apt-get clean || true && \
     # 创建符号链接 \
     if [ -f \"/app/models/MFD/YOLO/yolo_v8_mfd.pt\" ]; then \
       ln -sf /app/models/MFD/YOLO/yolo_v8_mfd.pt /app/models/MFD/YOLO/yolo_v8_ft.pt; \
     fi && \
     # 修补PDF Extract Kit \
     python3 -c \"import os, sys, json, magic_pdf; \
     pdf_extract_kit_path = os.path.join(os.path.dirname(magic_pdf.__file__), 'model', 'pdf_extract_kit.py'); \
     if os.path.exists(pdf_extract_kit_path): \
       with open(pdf_extract_kit_path, 'r') as f: \
         content = f.read(); \
       if 'models_dir, self.configs[\\'weights\\'][self.mfd_model_name]' in content: \
         content = content.replace('models_dir, self.configs[\\'weights\\'][self.mfd_model_name]', \
                                  'models_dir, self.configs.get(\\'weights\\', {}).get(self.mfd_model_name, f\\\\\\'MFD/YOLO/{self.mfd_model_name}.pt\\\\\\')'); \
         with open(pdf_extract_kit_path, 'w') as f: \
           f.write(content); \
     \" && \
     # 启动应用 \
     python -m uvicorn app:app --host 0.0.0.0 --port 8000 --workers 1"]