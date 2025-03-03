#!/bin/bash

echo "重新启动 MinerU 服务..."

# 停止当前运行的容器
echo "停止当前运行的容器..."
docker compose down

# 确保模型目录存在
echo "确保模型目录存在..."
mkdir -p models/MFD/YOLO
mkdir -p models/layoutlmv3-base-chinese
mkdir -p models/layoutreader
mkdir -p models/rapid_table
mkdir -p models/unimernet_small
mkdir -p models/yolo_v8_mfd

# 检查模型文件是否存在，如果为空则删除
if [ -f "models/MFD/YOLO/yolo_v8_ft.pt" ] && [ ! -s "models/MFD/YOLO/yolo_v8_ft.pt" ]; then
    echo "删除空的模型文件..."
    rm -f models/MFD/YOLO/yolo_v8_ft.pt
fi

# 重新构建并启动容器
echo "重新构建并启动容器..."
docker compose up -d --build

echo "服务已重新启动！"
echo "可以通过 http://localhost:8000 访问 API"
echo "查看日志: docker compose logs -f" 