#!/bin/bash

# 创建必要的目录结构
mkdir -p /app/models/MFD/YOLO
mkdir -p /app/models/MFR
mkdir -p /app/models/Layout/YOLO
mkdir -p /app/models/TabRec/TableMaster

# 设置模型缓存路径
MODEL_CACHE="/root/.cache/huggingface/hub/models--opendatalab--PDF-Extract-Kit-1.0/snapshots/60416a2cabad3f7b7284b43ce37a99864484fba2/models"

# 复制并重命名模型文件
cp "${MODEL_CACHE}/MFD/YOLO/yolo_v8_ft.pt" /app/models/MFD/YOLO/yolo_v8_mfd.pt
cp "${MODEL_CACHE}/Layout/YOLO/doclayout_yolo_ft.pt" /app/models/Layout/YOLO/doclayout_yolo.pt
cp -r "${MODEL_CACHE}/MFR/unimernet_small_2501"/* /app/models/MFR/
cp -r "${MODEL_CACHE}/TabRec/TableMaster"/* /app/models/TabRec/TableMaster/

# 设置权限
chmod -R 755 /app/models

# 列出复制后的文件
echo "Copied model files:"
ls -R /app/models 