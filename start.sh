#!/bin/bash
# 文件名: start.sh

# 设置错误时退出
set -e

# 显示欢迎信息
echo "=== MinerU 一键启动脚本 ==="
echo "正在准备环境..."

# 确保目录存在
mkdir -p app data models scripts tests

# 检查 Docker 和 Docker Compose 是否安装
if ! command -v docker &> /dev/null; then
    echo "错误: Docker 未安装，请先安装 Docker"
    exit 1
fi

if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
    echo "错误: Docker Compose 未安装，请先安装 Docker Compose"
    exit 1
fi

# 检查 NVIDIA Docker 是否安装
if ! command -v nvidia-smi &> /dev/null; then
    echo "警告: NVIDIA 驱动未找到，GPU 加速可能不可用"
fi

# 停止并移除现有容器
echo "停止现有容器..."
docker-compose down 2>/dev/null || docker compose down 2>/dev/null || true

# 构建并启动容器
echo "构建并启动容器..."
docker-compose up -d --build || docker compose up -d --build

# 显示容器状态
echo "容器状态:"
docker-compose ps || docker compose ps

echo "=== MinerU 已启动 ==="
echo "API 地址: http://localhost:8000"
echo "Web 界面: http://localhost:80"
echo "查看日志: docker-compose logs -f mineru"
