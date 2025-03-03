#!/bin/bash

echo "开始修复模型文件问题..."

# 检查模型目录是否存在
if [ ! -d "models" ]; then
    echo "模型目录不存在，创建目录..."
    mkdir -p models
fi

# 检查模型文件
echo "检查模型文件..."

# 列出现有模型文件
echo "现有模型文件:"
find models -type f 2>/dev/null || echo "没有找到模型文件"

# 检查是否有 yolo_v8_mfd.pt 文件
if [ -f "models/MFD/YOLO/yolo_v8_mfd.pt" ]; then
    echo "找到 models/MFD/YOLO/yolo_v8_mfd.pt 文件"
    
    # 检查是否有 yolo_v8_ft.pt 文件
    if [ ! -f "models/MFD/YOLO/yolo_v8_ft.pt" ]; then
        echo "没有找到 yolo_v8_ft.pt 文件，将在容器内创建符号链接"
    fi
else
    echo "警告: 没有找到 yolo_v8_mfd.pt 文件"
fi

# 修改 docker-compose.yml 文件，确保模型目录以只读方式挂载
echo "检查 docker-compose.yml 文件..."
if grep -q "./models:/models" docker-compose.yml && ! grep -q "./models:/models:ro" docker-compose.yml; then
    echo "修改 docker-compose.yml 文件，将模型目录设置为只读挂载..."
    sed -i 's|- ./models:/models|- ./models:/models:ro|g' docker-compose.yml
    echo "docker-compose.yml 文件已修改"
fi

# 创建一个临时的 Dockerfile.fix 文件
echo "创建临时 Dockerfile.fix 文件..."
cat > Dockerfile.fix << 'EOF'
FROM alpine:latest

WORKDIR /app

CMD ["sh", "-c", "if [ -f /models/MFD/YOLO/yolo_v8_mfd.pt ] && [ ! -f /models/MFD/YOLO/yolo_v8_ft.pt ]; then mkdir -p /tmp/models/MFD/YOLO && cp /models/MFD/YOLO/yolo_v8_mfd.pt /tmp/models/MFD/YOLO/yolo_v8_ft.pt && echo '已创建 yolo_v8_ft.pt 文件副本'; else echo '无需修复'; fi"]
EOF

echo "临时 Dockerfile.fix 文件已创建"

# 构建并运行临时容器
echo "构建临时容器..."
docker build -t mineru-fix -f Dockerfile.fix .

echo "运行临时容器修复模型文件..."
docker run --rm -v $(pwd)/models:/models:ro -v $(pwd)/app:/app mineru-fix

echo "清理临时文件..."
rm -f Dockerfile.fix

echo "模型文件修复完成"
echo "请运行以下命令重启服务:"
echo "  ./cleanup.sh"
echo "  ./start.sh" 