#!/bin/bash

# 创建必要的目录
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
fi

if [ -f "/models/MFD/YOLO/yolo_v8_mfd.pt" ]; then
    echo "从服务器复制 yolo_v8_mfd.pt 模型文件..."
    cp /models/MFD/YOLO/yolo_v8_mfd.pt models/MFD/YOLO/
fi

# 创建符号链接确保路径正确
ln -sf models/yolo_v8_mfd models/MFD/YOLO/yolo_v8_mfd 2>/dev/null || true

# 显示模型目录结构
echo "模型目录结构："
find models -type f | sort

echo "模型文件复制完成！" 