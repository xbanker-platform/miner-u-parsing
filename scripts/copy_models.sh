#!/bin/bash

# 创建必要的目录结构
mkdir -p /app/models/MFD/YOLO
mkdir -p /app/models/MFR
mkdir -p /app/models/Layout/YOLO
mkdir -p /app/models/TabRec/TableMaster

# 设置模型缓存路径
MODEL_CACHE="/root/.cache/huggingface/hub/models--opendatalab--PDF-Extract-Kit-1.0/snapshots/*/models"

# 复制并重命名模型文件
find ${MODEL_CACHE} -name "yolo_v8_ft.pt" -exec cp {} /app/models/MFD/YOLO/yolo_v8_mfd.pt \;
find ${MODEL_CACHE} -name "doclayout_yolo_ft.pt" -exec cp {} /app/models/Layout/YOLO/doclayout_yolo.pt \;

# 复制MFR模型
find ${MODEL_CACHE} -path "*/MFR/unimernet_small_2501/*" -exec cp -r {} /app/models/MFR/ \;

# 复制TableMaster模型
find ${MODEL_CACHE} -path "*/TabRec/TableMaster/*" -exec cp -r {} /app/models/TabRec/TableMaster/ \;

# 设置权限
chmod -R 755 /app/models

# 创建符号链接，确保yolo_v8_ft.pt可用
ln -sf /app/models/MFD/YOLO/yolo_v8_mfd.pt /app/models/MFD/YOLO/yolo_v8_ft.pt

# 创建unimernet_small.onnx符号链接（如果需要）
if [ ! -f /app/models/MFR/unimernet_small.onnx ] && [ -f /app/models/MFR/pytorch_model.pth ]; then
  ln -sf /app/models/MFR/pytorch_model.pth /app/models/MFR/unimernet_small.onnx
fi

# 列出复制后的文件
echo "Copied model files:"
ls -R /app/models 