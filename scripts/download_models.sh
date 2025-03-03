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