#!/bin/bash

# 创建更新后的配置文件
cat > updated_magic-pdf.json << 'EOF'
{
    "bucket_info": {},
    "models-dir": "/root/.cache/modelscope/hub/models/opendatalab/PDF-Extract-Kit-1___0/models",
    "layoutreader-model-dir": "/root/.cache/modelscope/hub/models/ppaanngggg/layoutreader",
    "device-mode": "cuda",
    "layout-config": {
        "model": "doclayout_yolo",
        "enable": true
    },
    "formula-config": {
        "mfd_model": "yolo_v8_mfd",
        "mfr_model": "unimernet_small",
        "enable": true
    },
    "table-config": {
        "model": "rapid_table",
        "sub_model": "slanet_plus",
        "enable": true,
        "max_time": 400
    },
    "config_version": "1.1.1"
}
EOF

# 将配置文件复制到容器中
docker cp updated_magic-pdf.json mineru-service-official:/app/magic-pdf.json
docker cp updated_magic-pdf.json mineru-service-official:/root/magic-pdf.json
docker cp updated_magic-pdf.json mineru-service-official:/home/root/magic-pdf.json

# 创建符号链接，确保app.py能找到模型
docker exec -it mineru-service-official bash -c "mkdir -p /tmp/models/MFD/YOLO && \
ln -sf /root/.cache/modelscope/hub/models/opendatalab/PDF-Extract-Kit-1___0/models/MFD/YOLO/yolo_v8_ft.pt /tmp/models/MFD/YOLO/yolo_v8_ft.pt && \
mkdir -p /tmp/layoutreader && \
ln -sf /root/.cache/modelscope/hub/models/ppaanngggg/layoutreader/* /tmp/layoutreader/ && \
echo '符号链接创建成功'"

# 设置环境变量
docker exec -it mineru-service-official bash -c "echo 'export MINERU_TOOLS_CONFIG_JSON=/app/magic-pdf.json' >> /root/.bashrc"

# 重启容器
docker restart mineru-service-official

echo "配置文件已更新，符号链接已创建，容器已重启" 