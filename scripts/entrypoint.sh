#!/bin/bash
set -e

# 激活虚拟环境
source /opt/mineru_venv/bin/activate

# 确保配置文件存在
if [ ! -f "/root/magic-pdf.json" ]; then
  echo "Configuration file not found, creating default configuration..."
  cat > /root/magic-pdf.json << 'EOL'
{
  "bucket_info": {
    "bucket-name-1": ["ak", "sk", "endpoint"],
    "bucket-name-2": ["ak", "sk", "endpoint"]
  },
  "models-dir": "/app/models",
  "layoutreader-model-dir": "/app/models/layoutreader",
  "device-mode": "cuda",
  "layout-config": {
    "model": "doclayout_yolo"
  },
  "formula-config": {
    "mfd_model": "yolo_v8_mfd",
    "mfr_model": "unimernet_small",
    "enable": true
  },
  "table-config": {
    "model": "rapid_table",
    "sub_model": "slanet_plus",
    "enable": true
  },
  "llm-aided-config": {
    "formula_aided": {
      "api_key": "your_api_key",
      "base_url": "https://dashscope.aliyuncs.com/compatible-mode/v1",
      "model": "qwen2.5-7b-instruct",
      "enable": false
    },
    "text_aided": {
      "api_key": "your_api_key",
      "base_url": "https://dashscope.aliyuncs.com/compatible-mode/v1",
      "model": "qwen2.5-7b-instruct",
      "enable": false
    },
    "title_aided": {
      "api_key": "your_api_key",
      "base_url": "https://dashscope.aliyuncs.com/compatible-mode/v1",
      "model": "qwen2.5-32b-instruct",
      "enable": false
    }
  },
  "config_version": "1.1.1",
  "weights": {
    "yolo_v8_mfd": "MFD/YOLO/yolo_v8_mfd.pt",
    "unimernet_small": "MFR/unimernet_small.onnx",
    "doclayout_yolo": "Layout/YOLO/doclayout_yolo.pt"
  }
}
EOL
fi

# 运行初始化脚本
if [ -f "/app/scripts/download_models.sh" ]; then
  echo "Running download_models.sh..."
  /app/scripts/download_models.sh
fi

if [ -f "/app/scripts/copy_models.sh" ]; then
  echo "Running copy_models.sh..."
  /app/scripts/copy_models.sh
fi

# 创建符号链接，确保yolo_v8_ft.pt可用
if [ -f "/app/models/MFD/YOLO/yolo_v8_mfd.pt" ]; then
  echo "Creating symbolic link for yolo_v8_ft.pt..."
  ln -sf /app/models/MFD/YOLO/yolo_v8_mfd.pt /app/models/MFD/YOLO/yolo_v8_ft.pt
fi

# 修补PDF Extract Kit库
echo "Patching PDF Extract Kit library..."
cat > /tmp/patch_pdf_extract_kit.py << 'EOL'
import os
import sys
import json
from pathlib import Path

def patch_config():
    """修补配置文件"""
    config_path = os.path.expanduser("~/magic-pdf.json")
    
    try:
        with open(config_path, 'r') as f:
            config = json.load(f)
        
        # 确保weights配置存在
        if 'weights' not in config:
            config['weights'] = {}
        
        # 添加yolo_v8_ft的配置
        config['weights']['yolo_v8_ft'] = "MFD/YOLO/yolo_v8_ft.pt"
        config['weights']['yolo_v8_mfd'] = "MFD/YOLO/yolo_v8_mfd.pt"
        config['weights']['unimernet_small'] = "MFR/unimernet_small.onnx"
        config['weights']['doclayout_yolo'] = "Layout/YOLO/doclayout_yolo.pt"
        
        # 保存修改后的配置
        with open(config_path, 'w') as f:
            json.dump(config, f, indent=4)
            
        print(f"配置文件已修补: {config_path}")
    except Exception as e:
        print(f"修补配置文件失败: {e}")

def patch_model_paths():
    """创建必要的符号链接"""
    try:
        models_dir = "/app/models"
        
        # 确保目录存在
        os.makedirs(f"{models_dir}/MFD/YOLO", exist_ok=True)
        
        # 创建符号链接
        if os.path.exists(f"{models_dir}/MFD/YOLO/yolo_v8_mfd.pt") and not os.path.exists(f"{models_dir}/MFD/YOLO/yolo_v8_ft.pt"):
            os.symlink(f"{models_dir}/MFD/YOLO/yolo_v8_mfd.pt", f"{models_dir}/MFD/YOLO/yolo_v8_ft.pt")
            print("已创建符号链接: yolo_v8_mfd.pt -> yolo_v8_ft.pt")
    except Exception as e:
        print(f"创建符号链接失败: {e}")

def monkey_patch_pdf_extract_kit():
    """修补PDF Extract Kit库"""
    try:
        # 找到pdf_extract_kit.py文件
        import magic_pdf
        pdf_extract_kit_path = os.path.join(os.path.dirname(magic_pdf.__file__), "model", "pdf_extract_kit.py")
        
        if os.path.exists(pdf_extract_kit_path):
            # 读取文件内容
            with open(pdf_extract_kit_path, 'r') as f:
                content = f.read()
            
            # 修改代码
            if "models_dir, self.configs['weights'][self.mfd_model_name]" in content:
                content = content.replace(
                    "models_dir, self.configs['weights'][self.mfd_model_name]",
                    "models_dir, self.configs.get('weights', {}).get(self.mfd_model_name, f\"MFD/YOLO/{self.mfd_model_name}.pt\")"
                )
                
                # 写回文件
                with open(pdf_extract_kit_path, 'w') as f:
                    f.write(content)
                
                print(f"已修补文件: {pdf_extract_kit_path}")
            else:
                print("未找到需要修补的代码")
        else:
            print(f"未找到文件: {pdf_extract_kit_path}")
    except Exception as e:
        print(f"修补PDF Extract Kit失败: {e}")

if __name__ == "__main__":
    print("应用补丁...")
    patch_config()
    patch_model_paths()
    monkey_patch_pdf_extract_kit()
    print("补丁应用完成")
EOL

# 运行补丁脚本
python3 /tmp/patch_pdf_extract_kit.py

# 检查环境
echo "Checking environment..."
nvidia-smi || echo "NVIDIA driver not found or not working"

# 检查模型文件
echo "Checking model files..."
ls -la /app/models/MFD/YOLO/
ls -la /app/models/Layout/YOLO/
ls -la /app/models/MFR/ || echo "MFR models not found"

# 检查配置文件
echo "Checking configuration..."
cat /root/magic-pdf.json

# 启动应用
echo "Starting application..."
exec "$@" 