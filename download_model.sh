#!/bin/bash

# 创建必要的目录
mkdir -p models/MFD/YOLO
mkdir -p models/layoutlmv3-base-chinese
mkdir -p models/layoutreader
mkdir -p models/rapid_table
mkdir -p models/unimernet_small
mkdir -p models/yolo_v8_mfd

# 下载 yolo_v8_ft.pt 模型
echo "下载 yolo_v8_ft.pt 模型..."
wget -q --show-progress https://github.com/opendatalab/MinerU/raw/master/models/MFD/YOLO/yolo_v8_ft.pt -O models/MFD/YOLO/yolo_v8_ft.pt

# 检查文件是否下载成功
if [ ! -s "models/MFD/YOLO/yolo_v8_ft.pt" ]; then
    echo "警告: 从 GitHub 下载 yolo_v8_ft.pt 模型失败或文件为空！"
    rm -f models/MFD/YOLO/yolo_v8_ft.pt
    
    # 尝试从其他来源下载
    echo "尝试从其他来源下载..."
    wget -q --show-progress https://huggingface.co/opendatalab/yolo_v8_mfd/resolve/main/yolo_v8_ft.pt -O models/MFD/YOLO/yolo_v8_ft.pt
    
    # 再次检查文件
    if [ ! -s "models/MFD/YOLO/yolo_v8_ft.pt" ]; then
        echo "错误: 下载 yolo_v8_ft.pt 模型失败！"
    else
        echo "下载成功！"
    fi
else
    echo "下载成功！"
fi

# 显示文件大小
echo "文件大小："
ls -la models/MFD/YOLO/yolo_v8_ft.pt

# 复制模型文件到容器
echo "复制模型文件到容器..."
docker cp models/MFD/YOLO/yolo_v8_ft.pt mineru-service:/models/MFD/YOLO/yolo_v8_ft.pt

echo "完成！" 