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

# 创建必要的模型目录
mkdir -p /models/MFD/YOLO
mkdir -p /models/layoutlmv3-base-chinese
mkdir -p /models/layoutreader
mkdir -p /models/rapid_table
mkdir -p /models/unimernet_small
mkdir -p /models/yolo_v8_mfd

# 检查模型文件是否存在，如果不存在或为空则下载
if [ ! -f "/models/MFD/YOLO/yolo_v8_ft.pt" ] || [ ! -s "/models/MFD/YOLO/yolo_v8_ft.pt" ]; then
    echo "模型文件不存在或为空，开始下载..."
    
    # 下载模型文件
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

# 启动应用
echo "启动应用..."
exec uvicorn app:app --host 0.0.0.0 --port 8000 