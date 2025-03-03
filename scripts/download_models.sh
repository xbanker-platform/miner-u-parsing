#!/bin/bash
set -e

echo "Installing huggingface_hub..."
pip install huggingface_hub

echo "Downloading models from Hugging Face..."
python3 - << 'EOF'
from huggingface_hub import snapshot_download
import os
import json
import shutil

# 下载模型
model_dir = snapshot_download(repo_id="opendatalab/PDF-Extract-Kit-1.0")
layoutreader_model_dir = snapshot_download(repo_id="hantian/layoutreader")

print(f"model_dir is: {model_dir}")
print(f"layoutreader_model_dir is: {layoutreader_model_dir}")

# 创建配置文件
config = {
    "bucket_info": {
        "bucket-name-1": ["ak", "sk", "endpoint"],
        "bucket-name-2": ["ak", "sk", "endpoint"]
    },
    "models-dir": "/app/models",
    "layoutreader-model-dir": "/app/models/layoutreader",
    "device-mode": "cuda",
    "layout-config": {
        "model": "doclayout_yolo"
    },
    "formula-config": {
        "mfd_model": "yolo_v8_mfd",
        "mfr_model": "unimernet_small",
        "enable": True
    },
    "table-config": {
        "model": "rapid_table",
        "sub_model": "slanet_plus",
        "enable": True
    },
    "llm-aided-config": {
        "formula_aided": {
            "api_key": "your_api_key",
            "base_url": "https://dashscope.aliyuncs.com/compatible-mode/v1",
            "model": "qwen2.5-7b-instruct",
            "enable": False
        },
        "text_aided": {
            "api_key": "your_api_key",
            "base_url": "https://dashscope.aliyuncs.com/compatible-mode/v1",
            "model": "qwen2.5-7b-instruct",
            "enable": False
        },
        "title_aided": {
            "api_key": "your_api_key",
            "base_url": "https://dashscope.aliyuncs.com/compatible-mode/v1",
            "model": "qwen2.5-32b-instruct",
            "enable": False
        }
    },
    "config_version": "1.1.1",
    "weights": {
        "yolo_v8_mfd": "MFD/YOLO/yolo_v8_mfd.pt",
        "unimernet_small": "MFR/unimernet_small.onnx",
        "doclayout_yolo": "Layout/YOLO/doclayout_yolo.pt"
    }
}

# 保存配置文件
with open('/root/magic-pdf.json', 'w') as f:
    json.dump(config, f, indent=2)

print("The configuration file has been configured successfully, the path is: /root/magic-pdf.json")

# 复制模型文件到指定目录
try:
    shutil.copytree(os.path.join(model_dir, "models"), "/root/magic-pdf-models")
    print("Models downloaded successfully to ./models directory")
except Exception as e:
    print(f"Error copying models: {e}")
EOF

# 复制模型文件
mkdir -p /app/models/MFD/YOLO
mkdir -p /app/models/MFR
mkdir -p /app/models/Layout/YOLO
mkdir -p /app/models/TabRec/TableMaster
mkdir -p /app/models/layoutreader

# 复制模型文件
cp -r /root/magic-pdf-models/* /app/models/ || echo "cp: cannot stat '/root/magic-pdf-models/*': No such file or directory"

# 确保模型文件存在
if [ ! -f "/app/models/MFD/YOLO/yolo_v8_mfd.pt" ]; then
  # 尝试从缓存目录复制
  find /root/.cache/huggingface/hub -name "yolo_v8_ft.pt" -exec cp {} /app/models/MFD/YOLO/yolo_v8_mfd.pt \;
fi

if [ ! -f "/app/models/Layout/YOLO/doclayout_yolo.pt" ]; then
  # 尝试从缓存目录复制
  find /root/.cache/huggingface/hub -name "doclayout_yolo_ft.pt" -exec cp {} /app/models/Layout/YOLO/doclayout_yolo.pt \;
fi

# 创建符号链接，确保兼容性
ln -sf /app/models/MFD/YOLO/yolo_v8_mfd.pt /app/models/MFD/YOLO/yolo_v8_ft.pt

echo "Model setup completed." 