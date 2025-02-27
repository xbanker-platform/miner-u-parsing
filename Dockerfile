# 使用 NVIDIA CUDA 基础镜像
FROM nvidia/cuda:12.1.0-base-ubuntu22.04

# 设置工作目录
WORKDIR /app

# 设置 pip 缓存目录
ENV PIP_NO_CACHE_DIR=1

# 合并 RUN 命令来减少层数
RUN apt-get update && apt-get install -y \
    python3-pip \
    python3-dev \
    && rm -rf /var/lib/apt/lists/* \
    && pip3 install -U magic-pdf[full] --extra-index-url https://wheels.myhloli.com -i https://pypi.org/simple \
    && pip3 install fastapi uvicorn python-multipart \
    && mkdir -p /root && echo '{"device-mode": "cuda"}' > /root/magic-pdf.json \
    && pip3 install paddlepaddle-gpu==3.0.0rc1 -i https://www.paddlepaddle.org.cn/packages/stable/cu118/

# 复制 API 服务代码
COPY ./app.py .

# 暴露端口
EXPOSE 8000

# 启动服务
CMD ["uvicorn", "app:app", "--host", "0.0.0.0", "--port", "8000"]
