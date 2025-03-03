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

# 启动应用
echo "启动应用..."
exec uvicorn app:app --host 0.0.0.0 --port 8000 