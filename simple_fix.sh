#!/bin/bash

echo "开始简单修复模型文件问题..."

# 停止并删除现有容器
echo "停止并删除现有容器..."
docker compose down

# 修改 docker-compose.yml 文件
echo "修改 docker-compose.yml 文件..."
cp docker-compose.yml docker-compose.yml.bak
cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  mineru:
    build:
      context: .
      dockerfile: Dockerfile
    container_name: mineru-service
    restart: unless-stopped
    ports:
      - "8000:8000"
    volumes:
      - ./app:/app
      - ./models:/models:ro
      - ./output:/output
      - ./uploads:/uploads
      - ./data:/data
      - ./config:/root
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: 1
              capabilities: [gpu]
    environment:
      - MINERU_TOOLS_CONFIG_JSON=/app/magic-pdf.json
      - CUDA_VISIBLE_DEVICES=0
      - PYTHONUNBUFFERED=1
      - UVICORN_TIMEOUT=300
    working_dir: /app
    command: bash -c "chmod +x /app/start_app.sh && /app/start_app.sh"
    ulimits:
      nofile:
        soft: 65536
        hard: 65536

  nginx:
    image: nginx:latest
    ports:
      - "80:80"
    volumes:
      - ./nginx.conf:/etc/nginx/conf.d/default.conf
    depends_on:
      - mineru
EOF

echo "docker-compose.yml 文件已修改"

# 创建配置文件
echo "创建配置文件..."
mkdir -p config
cat > config/magic-pdf.json << 'EOF'
{
    "bucket_info":{},
    "models-dir":"/tmp/models",
    "layoutreader-model-dir":"/tmp/models/layoutreader",
    "device-mode":"cuda",
    "layout-config": {
        "model": "layoutlmv3"
    },
    "formula-config": {
        "mfd_model": "yolo_v8_mfd",
        "mfr_model": "unimernet_small",
        "enable": true
    },
    "table-config": {
        "model": "rapid_table",
        "enable": true,
        "max_time": 400
    },
    "config_version": "1.0.0"
}
EOF

echo "配置文件已创建"

# 启动服务
echo "启动服务..."
docker compose up -d --build

echo "修复完成！请检查服务是否正常运行："
echo "docker compose logs -f mineru" 