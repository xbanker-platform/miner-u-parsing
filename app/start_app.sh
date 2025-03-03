#!/bin/bash

# 确保配置文件存在
if [ ! -f "/app/magic-pdf.json" ]; then
    echo "配置文件不存在，创建默认配置..."
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
    }' > /app/magic-pdf.json
    
    # 同时复制到用户目录
    cp /app/magic-pdf.json /root/magic-pdf.json
fi

# 设置环境变量
export MINERU_TOOLS_CONFIG_JSON=/app/magic-pdf.json

# 启动应用
exec uvicorn app:app --host 0.0.0.0 --port 8000 