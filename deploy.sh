#!/bin/bash

# 显示彩色输出
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${GREEN}===== MinerU 一键部署脚本 =====${NC}"

# 创建必要的目录
echo -e "${YELLOW}创建必要的目录...${NC}"
mkdir -p app models/MFD/YOLO models/layoutlmv3-base-chinese models/layoutreader models/rapid_table models/unimernet_small models/yolo_v8_mfd output uploads scripts data config

# 下载 Dockerfile
echo -e "${YELLOW}下载 Dockerfile...${NC}"
wget -q https://github.com/opendatalab/MinerU/raw/master/Dockerfile -O Dockerfile

# 创建 docker-compose.yml 文件
echo -e "${YELLOW}创建 docker-compose.yml 文件...${NC}"
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

# 创建 nginx.conf 文件
echo -e "${YELLOW}创建 nginx.conf 文件...${NC}"
cat > nginx.conf << 'EOF'
server {
    listen 80;
    
    client_max_body_size 100M;
    proxy_read_timeout 300s;
    proxy_connect_timeout 75s;
    
    location / {
        proxy_pass http://mineru:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
EOF

# 创建启动脚本
echo -e "${YELLOW}创建启动脚本...${NC}"
cat > app/start_app.sh << 'EOF'
#!/bin/bash

# 检查多个位置的配置文件
CONFIG_PATHS=("/app/magic-pdf.json" "/root/magic-pdf.json" "$HOME/magic-pdf.json")
CONFIG_FOUND=false

for CONFIG_PATH in "${CONFIG_PATHS[@]}"; do
    if [ -f "$CONFIG_PATH" ]; then
        echo "找到配置文件: $CONFIG_PATH"
        export MINERU_TOOLS_CONFIG_JSON="$CONFIG_PATH"
        CONFIG_FOUND=true
        break
    fi
done

# 如果没有找到配置文件，则创建一个
if [ "$CONFIG_FOUND" = false ]; then
    echo "配置文件不存在，创建默认配置..."
    
    # 尝试在多个位置创建配置文件
    for CONFIG_PATH in "${CONFIG_PATHS[@]}"; do
        CONFIG_DIR=$(dirname "$CONFIG_PATH")
        mkdir -p "$CONFIG_DIR" 2>/dev/null || true
        
        if [ -w "$CONFIG_DIR" ]; then
            echo '{
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
            }' > "$CONFIG_PATH"
            
            echo "配置文件已创建: $CONFIG_PATH"
            export MINERU_TOOLS_CONFIG_JSON="$CONFIG_PATH"
            CONFIG_FOUND=true
            break
        else
            echo "无法写入目录 $CONFIG_DIR，尝试下一个位置"
        fi
    done
fi

# 如果仍然没有找到或创建配置文件，则报错
if [ "$CONFIG_FOUND" = false ]; then
    echo "错误: 无法创建配置文件！"
    exit 1
fi

# 显示当前使用的配置文件路径
echo "使用配置文件: $MINERU_TOOLS_CONFIG_JSON"

# 确保配置文件存在于多个位置（复制到其他位置）
for CONFIG_PATH in "${CONFIG_PATHS[@]}"; do
    if [ "$CONFIG_PATH" != "$MINERU_TOOLS_CONFIG_JSON" ]; then
        CONFIG_DIR=$(dirname "$CONFIG_PATH")
        if [ -w "$CONFIG_DIR" ]; then
            cp "$MINERU_TOOLS_CONFIG_JSON" "$CONFIG_PATH" 2>/dev/null || true
            echo "复制配置文件到: $CONFIG_PATH"
        fi
    fi
done

# 创建临时模型目录并复制模型文件
echo "创建临时模型目录..."
mkdir -p /tmp/models/MFD/YOLO

# 检查是否存在 yolo_v8_mfd.pt 文件并复制
if [ -f "/models/MFD/YOLO/yolo_v8_mfd.pt" ]; then
    echo "复制 yolo_v8_mfd.pt 到临时目录..."
    cp /models/MFD/YOLO/yolo_v8_mfd.pt /tmp/models/MFD/YOLO/
    
    # 创建 yolo_v8_ft.pt 文件（复制 yolo_v8_mfd.pt）
    echo "创建 yolo_v8_ft.pt 文件..."
    cp /tmp/models/MFD/YOLO/yolo_v8_mfd.pt /tmp/models/MFD/YOLO/yolo_v8_ft.pt
    
    echo "模型文件已准备就绪"
else
    echo "错误: 找不到源模型文件 /models/MFD/YOLO/yolo_v8_mfd.pt"
    exit 1
fi

# 修改所有配置文件中的模型目录路径
for CONFIG_PATH in "${CONFIG_PATHS[@]}"; do
    if [ -f "$CONFIG_PATH" ]; then
        echo "更新配置文件 $CONFIG_PATH 中的模型目录路径..."
        sed -i 's|"models-dir":"/models"|"models-dir":"/tmp/models"|g' "$CONFIG_PATH"
    fi
done

# 显示模型目录结构
echo "临时模型目录结构："
find /tmp/models -type f | sort

# 启动应用
echo "启动应用..."
exec uvicorn app:app --host 0.0.0.0 --port 8000
EOF

# 创建清理脚本
echo -e "${YELLOW}创建清理脚本...${NC}"
cat > cleanup.sh << 'EOF'
#!/bin/bash

echo "清理 Docker 资源..."

# 停止所有运行中的容器
echo "停止所有容器..."
docker stop $(docker ps -a -q) 2>/dev/null || true

# 删除所有容器
echo "删除所有容器..."
docker rm $(docker ps -a -q) 2>/dev/null || true

# 删除 mineru 相关镜像
echo "删除 mineru 相关镜像..."
docker rmi $(docker images | grep mineru | awk '{print $3}') 2>/dev/null || true

# 删除未使用的卷
echo "删除未使用的卷..."
docker volume prune -f

# 删除未使用的网络
echo "删除未使用的网络..."
docker network prune -f

# 删除悬空镜像
echo "删除悬空镜像..."
docker image prune -f

echo "清理完成！"
EOF

# 创建配置文件
echo -e "${YELLOW}创建配置文件...${NC}"
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

# 下载模型文件
echo -e "${YELLOW}下载模型文件...${NC}"
wget -q --show-progress https://huggingface.co/opendatalab/yolo_v8_mfd/resolve/main/yolo_v8_mfd.pt -O models/MFD/YOLO/yolo_v8_mfd.pt

# 设置文件权限
echo -e "${YELLOW}设置文件权限...${NC}"
chmod +x app/start_app.sh cleanup.sh

# 启动服务
echo -e "${YELLOW}启动服务...${NC}"
docker compose up -d --build

echo -e "${GREEN}MinerU 服务已启动，API 可通过 http://localhost:8000 访问${NC}"
echo -e "${YELLOW}查看日志: docker compose logs -f mineru${NC}" 