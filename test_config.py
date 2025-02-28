from magic_pdf.model.pdf_extract_kit import CustomPEKModel
import json

# 读取配置
with open('/root/magic-pdf.json', 'r') as f:
    config = json.load(f)

print("Current config:", json.dumps(config, indent=2))

# 检查模型文件
import os
model_dir = config.get('models-dir', '/app/models')
print("\nChecking model files in:", model_dir)
for root, dirs, files in os.walk(model_dir):
    for file in files:
        print(os.path.join(root, file))

# 尝试初始化模型
try:
    model = CustomPEKModel(
        models_dir=model_dir,
        device_mode='cuda',
        mfd_model='yolo_v8_mfd',
        mfr_model='unimernet_small',
        layout_model='doclayout_yolo'
    )
    print("\nModel initialization successful!")
except Exception as e:
    print("\nError initializing model:", str(e)) 