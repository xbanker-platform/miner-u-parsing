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
                "models-dir":"/tmp/models",
                "layoutreader-model-dir":"/tmp/models/layoutreader",
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

# 创建临时模型目录并复制模型文件
echo "创建临时模型目录..."
mkdir -p /tmp/models/MFD/YOLO

# 检查是否存在 yolo_v8_mfd.pt 文件并复制
if [ -f "/models/MFD/YOLO/yolo_v8_mfd.pt" ]; then
    echo "复制 yolo_v8_mfd.pt 到临时目录..."
    cp /models/MFD/YOLO/yolo_v8_mfd.pt /tmp/models/MFD/YOLO/
    
    # 创建 yolo_v8_ft.pt 文件（复制 yolo_v8_mfd.pt）
    echo "创建 yolo_v8_ft.pt 文件..."
    cp /tmp/models/MFD/YOLO/yolo_v8_mfd.pt /tmp/models/MFD/YOLO/yolo_v8_ft.pt
    
    echo "模型文件已准备就绪"
else
    echo "错误: 找不到源模型文件 /models/MFD/YOLO/yolo_v8_mfd.pt"
    exit 1
fi

# 修改所有配置文件中的模型目录路径
for CONFIG_PATH in "${CONFIG_PATHS[@]}"; do
    if [ -f "$CONFIG_PATH" ]; then
        echo "更新配置文件 $CONFIG_PATH 中的模型目录路径..."
        sed -i 's|"models-dir":"/models"|"models-dir":"/tmp/models"|g' "$CONFIG_PATH"
    fi
done

# 显示模型目录结构
echo "临时模型目录结构："
find /tmp/models -type f | sort

# 启动应用
echo "启动应用..."
exec uvicorn app:app --host 0.0.0.0 --port 8000 