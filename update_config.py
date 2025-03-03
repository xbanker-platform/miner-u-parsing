 #!/usr/bin/env python3
import json

# 更新后的配置
updated_config = {
    "bucket_info": {},
    "models-dir": "/models",
    "layoutreader-model-dir": "/models/layoutreader",
    "device-mode": "cuda",
    "layout-config": {
        "model": "layoutlmv3",
        "model_path": "/models/layoutlmv3-base-chinese",
        "enable": False
    },
    "formula-config": {
        "mfd_model": "yolo_v8_mfd",
        "mfr_model": "unimernet_small",
        "enable": False
    },
    "table-config": {
        "model": "rapid_table",
        "enable": False,
        "max_time": 400
    },
    "config_version": "1.1.1"
}

# 将配置写入文件
with open("updated_magic-pdf.json", "w") as f:
    json.dump(updated_config, f, indent=4)

print("配置文件已更新，请将其复制到容器中的/app/magic-pdf.json")