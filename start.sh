#!/bin/bash

# 清理之前的容器和镜像
echo "清理之前的 Docker 容器和镜像..."
docker stop $(docker ps -a -q) 2>/dev/null || true
docker rm $(docker ps -a -q) 2>/dev/null || true
docker rmi $(docker images -q mineru:latest) 2>/dev/null || true

# 创建必要的目录
echo "创建必要的目录..."
mkdir -p app models output uploads scripts data

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

# 启动 Docker 容器
echo "启动 Docker 容器..."
docker compose up -d --build

echo "MinerU 服务已启动，API 可通过 http://localhost:8000 访问" 