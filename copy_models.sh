#!/bin/bash

# 创建必要的目录
echo "创建必要的目录..."
mkdir -p models/MFD/YOLO
mkdir -p models/layoutlmv3-base-chinese
mkdir -p models/layoutreader
mkdir -p models/rapid_table
mkdir -p models/unimernet_small
mkdir -p models/yolo_v8_mfd

# 如果服务器上有模型文件，则复制
if [ -f "/models/MFD/YOLO/yolo_v8_ft.pt" ]; then
    echo "从服务器复制 yolo_v8_ft.pt 模型文件..."
    cp /models/MFD/YOLO/yolo_v8_ft.pt models/MFD/YOLO/
else
    echo "服务器上没有找到 yolo_v8_ft.pt 模型文件"
    
    # 如果有 yolo_v8_mfd.pt 文件，可以复制并重命名
    if [ -f "/models/MFD/YOLO/yolo_v8_mfd.pt" ]; then
        echo "从服务器复制 yolo_v8_mfd.pt 并创建 yolo_v8_ft.pt..."
        cp /models/MFD/YOLO/yolo_v8_mfd.pt models/MFD/YOLO/yolo_v8_ft.pt
    else
        echo "尝试从 Hugging Face 下载 yolo_v8_ft.pt..."
        wget -q --show-progress https://huggingface.co/opendatalab/yolo_v8_mfd/resolve/main/yolo_v8_ft.pt -O models/MFD/YOLO/yolo_v8_ft.pt
    fi
fi

if [ -f "/models/MFD/YOLO/yolo_v8_mfd.pt" ]; then
    echo "从服务器复制 yolo_v8_mfd.pt 模型文件..."
    cp /models/MFD/YOLO/yolo_v8_mfd.pt models/MFD/YOLO/
else
    echo "服务器上没有找到 yolo_v8_mfd.pt 模型文件，尝试下载..."
    wget -q --show-progress https://huggingface.co/opendatalab/yolo_v8_mfd/resolve/main/yolo_v8_mfd.pt -O models/MFD/YOLO/yolo_v8_mfd.pt
fi

# 确保文件权限正确
chmod -R 755 models

# 显示模型目录结构
echo "模型目录结构："
find models -type f | sort

echo "模型文件复制完成！" 