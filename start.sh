#!/bin/bash

# 清理之前的容器和镜像
echo "清理之前的 Docker 容器和镜像..."
docker stop $(docker ps -a -q) 2>/dev/null || true
docker rm $(docker ps -a -q) 2>/dev/null || true
docker rmi $(docker images -q mineru:latest) 2>/dev/null || true

# 创建必要的目录
echo "创建必要的目录..."
mkdir -p app models output uploads scripts data config

# 创建下载脚本
echo "创建下载脚本..."
cat > scripts/download_models_hf_modified.py << 'EOF'
import os
import json
from huggingface_hub import snapshot_download
import requests

# 增加超时时间
requests.adapters.DEFAULT_TIMEOUT = 300  # 设置为5分钟

# 设置模型目录
models_dir = "/models"
layoutreader_dir = os.path.join(models_dir, "layoutreader")

# 创建目录
os.makedirs(models_dir, exist_ok=True)
os.makedirs(layoutreader_dir, exist_ok=True)

# 下载模型
print("开始下载模型...")

try:
    # 下载 layoutlmv3 模型
    print("下载 layoutlmv3 模型...")
    snapshot_download(
        repo_id="opendatalab/layoutlmv3-base-chinese", 
        local_dir=os.path.join(models_dir, "layoutlmv3-base-chinese"),
        local_dir_use_symlinks=False,
        revision="main"
    )
    
    # 下载 layoutreader 模型
    print("下载 layoutreader 模型...")
    snapshot_download(
        repo_id="opendatalab/layoutreader", 
        local_dir=layoutreader_dir,
        local_dir_use_symlinks=False,
        revision="main"
    )
    
    # 下载 formula 模型
    print("下载 formula 模型...")
    snapshot_download(
        repo_id="opendatalab/yolo_v8_mfd", 
        local_dir=os.path.join(models_dir, "yolo_v8_mfd"),
        local_dir_use_symlinks=False,
        revision="main"
    )
    snapshot_download(
        repo_id="opendatalab/unimernet_small", 
        local_dir=os.path.join(models_dir, "unimernet_small"),
        local_dir_use_symlinks=False,
        revision="main"
    )
    
    # 下载 table 模型
    print("下载 table 模型...")
    snapshot_download(
        repo_id="opendatalab/rapid_table", 
        local_dir=os.path.join(models_dir, "rapid_table"),
        local_dir_use_symlinks=False,
        revision="main"
    )
    
    print("所有模型下载完成！")
    
except Exception as e:
    print(f"下载模型时出错: {str(e)}")
    # 继续执行，不要因为下载失败而中断构建过程
    pass

# 创建配置文件
config = {
    "bucket_info": {},
    "models-dir": models_dir,
    "layoutreader-model-dir": layoutreader_dir,
    "device-mode": "cuda",
    "layout-config": {
        "model": "layoutlmv3"
    },
    "formula-config": {
        "mfd_model": "yolo_v8_mfd",
        "mfr_model": "unimernet_small",
        "enable": True
    },
    "table-config": {
        "model": "rapid_table",
        "enable": True,
        "max_time": 400
    },
    "config_version": "1.0.0"
}

# 保存配置文件
with open("/app/magic-pdf.json", "w") as f:
    json.dump(config, f, indent=4)

print("配置文件已创建")
EOF

# 创建模型下载脚本
echo "创建模型下载脚本..."
cat > scripts/download_models.sh << 'EOF'
#!/bin/bash

# 创建必要的目录
mkdir -p /models/MFD/YOLO
mkdir -p /models/layoutlmv3-base-chinese
mkdir -p /models/layoutreader
mkdir -p /models/rapid_table
mkdir -p /models/unimernet_small
mkdir -p /models/yolo_v8_mfd

# 下载模型文件
echo "开始下载模型文件..."

# 下载 yolo_v8_ft.pt 模型
if [ ! -f "/models/MFD/YOLO/yolo_v8_ft.pt" ]; then
    echo "下载 yolo_v8_ft.pt 模型..."
    wget -q --show-progress https://huggingface.co/opendatalab/yolo_v8_mfd/resolve/main/yolo_v8_ft.pt -O /models/MFD/YOLO/yolo_v8_ft.pt
fi

# 下载其他必要的模型文件
if [ ! -d "/models/layoutlmv3-base-chinese/pytorch_model.bin" ]; then
    echo "下载 layoutlmv3-base-chinese 模型..."
    wget -q --show-progress https://huggingface.co/opendatalab/layoutlmv3-base-chinese/resolve/main/pytorch_model.bin -O /models/layoutlmv3-base-chinese/pytorch_model.bin
fi

echo "模型下载完成！"

# 创建符号链接确保路径正确
ln -sf /models/yolo_v8_mfd /models/MFD/YOLO/yolo_v8_mfd 2>/dev/null || true

# 显示模型目录结构
echo "模型目录结构："
find /models -type f | sort
EOF

# 创建启动脚本
echo "创建启动脚本..."
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
                "models-dir":"/models",
                "layoutreader-model-dir":"/models/layoutreader",
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

# 检查模型文件是否存在，如果不存在则下载
if [ ! -f "/models/MFD/YOLO/yolo_v8_ft.pt" ]; then
    echo "模型文件不存在，开始下载..."
    
    # 创建必要的目录
    mkdir -p /models/MFD/YOLO
    
    # 下载模型文件
    echo "下载 yolo_v8_ft.pt 模型..."
    wget -q --show-progress https://huggingface.co/opendatalab/yolo_v8_mfd/resolve/main/yolo_v8_ft.pt -O /models/MFD/YOLO/yolo_v8_ft.pt
    
    echo "模型下载完成！"
fi

# 显示模型目录结构
echo "模型目录结构："
find /models -type f | sort

# 启动应用
echo "启动应用..."
exec uvicorn app:app --host 0.0.0.0 --port 8000
EOF

# 确保启动脚本有执行权限
chmod +x app/start_app.sh scripts/download_models.sh

# 创建配置文件
echo "创建配置文件..."
cat > config/magic-pdf.json << 'EOF'
{
    "bucket_info":{},
    "models-dir":"/models",
    "layoutreader-model-dir":"/models/layoutreader",
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

# 启动 Docker 容器
echo "启动 Docker 容器..."
docker compose up -d --build

echo "MinerU 服务已启动，API 可通过 http://localhost:8000 访问" 