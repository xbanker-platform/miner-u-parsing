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

# 检查模型文件是否存在
echo "检查模型文件..."

# 检查 yolo_v8_ft.pt 文件
if [ ! -f "/models/MFD/YOLO/yolo_v8_ft.pt" ]; then
    echo "警告: /models/MFD/YOLO/yolo_v8_ft.pt 文件不存在"
    
    # 检查是否存在 yolo_v8_mfd.pt 文件
    if [ -f "/models/MFD/YOLO/yolo_v8_mfd.pt" ]; then
        echo "找到 /models/MFD/YOLO/yolo_v8_mfd.pt 文件，创建符号链接..."
        # 创建符号链接
        ln -sf /models/MFD/YOLO/yolo_v8_mfd.pt /models/MFD/YOLO/yolo_v8_ft.pt 2>/dev/null || true
        
        if [ ! -f "/models/MFD/YOLO/yolo_v8_ft.pt" ]; then
            echo "无法创建符号链接，尝试在容器内部创建副本..."
            # 如果无法创建符号链接（可能是因为只读挂载），则尝试在容器内部创建副本
            mkdir -p /tmp/models/MFD/YOLO
            cp /models/MFD/YOLO/yolo_v8_mfd.pt /tmp/models/MFD/YOLO/yolo_v8_ft.pt
            
            # 修改配置文件中的模型目录路径
            sed -i 's|"models-dir":"/models"|"models-dir":"/tmp/models"|g' "$MINERU_TOOLS_CONFIG_JSON"
            echo "已将模型目录路径修改为 /tmp/models"
        fi
    else
        echo "错误: 找不到任何可用的模型文件！"
        exit 1
    fi
fi

# 显示模型目录结构
echo "模型目录结构："
find /models -type f | sort

# 如果使用了临时目录，也显示临时目录结构
if [ -d "/tmp/models" ]; then
    echo "临时模型目录结构："
    find /tmp/models -type f | sort
fi

# 启动应用
echo "启动应用..."
exec uvicorn app:app --host 0.0.0.0 --port 8000 