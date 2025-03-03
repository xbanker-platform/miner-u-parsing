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
if [ ! -f "/models/MFD/YOLO/yolo_v8_ft.pt" ] || [ ! -s "/models/MFD/YOLO/yolo_v8_ft.pt" ]; then
    echo "下载 yolo_v8_ft.pt 模型..."
    wget -q --show-progress https://huggingface.co/opendatalab/yolo_v8_mfd/resolve/main/yolo_v8_ft.pt -O /models/MFD/YOLO/yolo_v8_ft.pt
    
    # 检查文件是否下载成功
    if [ ! -s "/models/MFD/YOLO/yolo_v8_ft.pt" ]; then
        echo "警告: yolo_v8_ft.pt 模型下载失败或文件为空！"
        rm -f /models/MFD/YOLO/yolo_v8_ft.pt
        
        # 尝试使用 curl 下载
        echo "尝试使用 curl 下载..."
        curl -L https://huggingface.co/opendatalab/yolo_v8_mfd/resolve/main/yolo_v8_ft.pt -o /models/MFD/YOLO/yolo_v8_ft.pt
        
        # 再次检查文件
        if [ ! -s "/models/MFD/YOLO/yolo_v8_ft.pt" ]; then
            echo "错误: 使用 curl 下载 yolo_v8_ft.pt 模型也失败了！"
        else
            echo "使用 curl 下载成功！"
        fi
    fi
fi

# 下载其他必要的模型文件
if [ ! -f "/models/layoutlmv3-base-chinese/pytorch_model.bin" ] || [ ! -s "/models/layoutlmv3-base-chinese/pytorch_model.bin" ]; then
    echo "下载 layoutlmv3-base-chinese 模型..."
    wget -q --show-progress https://huggingface.co/opendatalab/layoutlmv3-base-chinese/resolve/main/pytorch_model.bin -O /models/layoutlmv3-base-chinese/pytorch_model.bin
    
    # 检查文件是否下载成功
    if [ ! -s "/models/layoutlmv3-base-chinese/pytorch_model.bin" ]; then
        echo "警告: layoutlmv3-base-chinese 模型下载失败或文件为空！"
        
        # 尝试使用 curl 下载
        echo "尝试使用 curl 下载..."
        curl -L https://huggingface.co/opendatalab/layoutlmv3-base-chinese/resolve/main/pytorch_model.bin -o /models/layoutlmv3-base-chinese/pytorch_model.bin
    fi
fi

# 下载 config.json 文件
if [ ! -f "/models/layoutlmv3-base-chinese/config.json" ]; then
    echo "下载 layoutlmv3-base-chinese 配置文件..."
    wget -q --show-progress https://huggingface.co/opendatalab/layoutlmv3-base-chinese/resolve/main/config.json -O /models/layoutlmv3-base-chinese/config.json
fi

# 下载 rapid_table 模型文件
if [ ! -f "/models/rapid_table/model.onnx" ]; then
    echo "下载 rapid_table 模型..."
    wget -q --show-progress https://huggingface.co/opendatalab/rapid_table/resolve/main/model.onnx -O /models/rapid_table/model.onnx
fi

# 下载 unimernet_small 模型文件
if [ ! -f "/models/unimernet_small/model.onnx" ]; then
    echo "下载 unimernet_small 模型..."
    wget -q --show-progress https://huggingface.co/opendatalab/unimernet_small/resolve/main/model.onnx -O /models/unimernet_small/model.onnx
fi

echo "模型下载完成！"

# 创建符号链接确保路径正确
ln -sf /models/yolo_v8_mfd /models/MFD/YOLO/yolo_v8_mfd 2>/dev/null || true

# 显示模型目录结构
echo "模型目录结构："
find /models -type f | sort

# 显示文件大小
echo "文件大小："
du -sh /models/*/* | sort -h 