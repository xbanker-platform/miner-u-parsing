#!/bin/bash

# 清理之前的容器和镜像
echo "清理之前的 Docker 容器和镜像..."
docker stop $(docker ps -a -q) 2>/dev/null || true
docker rm $(docker ps -a -q) 2>/dev/null || true
docker rmi $(docker images -q mineru:latest) 2>/dev/null || true

# 创建必要的目录
echo "创建必要的目录..."
mkdir -p app models output uploads scripts

# 下载模型下载脚本
echo "下载模型下载脚本..."
wget -O scripts/download_models_hf.py https://github.com/opendatalab/MinerU/raw/master/scripts/download_models_hf.py

# 启动 Docker 容器
echo "启动 Docker 容器..."
docker-compose up -d --build

echo "MinerU 服务已启动，API 可通过 http://localhost:8000 访问" 