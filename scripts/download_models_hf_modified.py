import os
import json
from huggingface_hub import snapshot_download
import requests

# 增加超时时间
requests.adapters.DEFAULT_TIMEOUT = 300  # 设置为5分钟

# 设置模型目录
models_dir = "/models"
layoutreader_dir = os.path.join(models_dir, "layoutreader")

# 创建目录
os.makedirs(models_dir, exist_ok=True)
os.makedirs(layoutreader_dir, exist_ok=True)
os.makedirs(os.path.join(models_dir, "MFD", "YOLO"), exist_ok=True)
os.makedirs(os.path.join(models_dir, "layoutlmv3-base-chinese"), exist_ok=True)
os.makedirs(os.path.join(models_dir, "rapid_table"), exist_ok=True)
os.makedirs(os.path.join(models_dir, "unimernet_small"), exist_ok=True)
os.makedirs(os.path.join(models_dir, "yolo_v8_mfd"), exist_ok=True)

# 下载模型
print("开始下载模型...")

try:
    # 下载 layoutlmv3 模型
    print("下载 layoutlmv3 模型...")
    snapshot_download(
        repo_id="opendatalab/layoutlmv3-base-chinese", 
        local_dir=os.path.join(models_dir, "layoutlmv3-base-chinese"),
        local_dir_use_symlinks=False,
        revision="main"
    )
    
    # 下载 layoutreader 模型
    print("下载 layoutreader 模型...")
    snapshot_download(
        repo_id="opendatalab/layoutreader", 
        local_dir=layoutreader_dir,
        local_dir_use_symlinks=False,
        revision="main"
    )
    
    # 下载 formula 模型
    print("下载 formula 模型...")
    snapshot_download(
        repo_id="opendatalab/yolo_v8_mfd", 
        local_dir=os.path.join(models_dir, "yolo_v8_mfd"),
        local_dir_use_symlinks=False,
        revision="main"
    )
    snapshot_download(
        repo_id="opendatalab/unimernet_small", 
        local_dir=os.path.join(models_dir, "unimernet_small"),
        local_dir_use_symlinks=False,
        revision="main"
    )
    
    # 下载 table 模型
    print("下载 table 模型...")
    snapshot_download(
        repo_id="opendatalab/rapid_table", 
        local_dir=os.path.join(models_dir, "rapid_table"),
        local_dir_use_symlinks=False,
        revision="main"
    )
    
    # 直接下载 yolo_v8_ft.pt 模型
    print("直接下载 yolo_v8_ft.pt 模型...")
    yolo_model_path = os.path.join(models_dir, "MFD", "YOLO", "yolo_v8_ft.pt")
    response = requests.get("https://huggingface.co/opendatalab/yolo_v8_mfd/resolve/main/yolo_v8_ft.pt", stream=True)
    response.raise_for_status()
    with open(yolo_model_path, 'wb') as f:
        for chunk in response.iter_content(chunk_size=8192):
            f.write(chunk)
    
    # 创建符号链接
    print("创建符号链接...")
    try:
        os.symlink(os.path.join(models_dir, "yolo_v8_mfd"), os.path.join(models_dir, "MFD", "YOLO", "yolo_v8_mfd"))
    except FileExistsError:
        print("符号链接已存在，跳过创建")
    
    print("所有模型下载完成！")
    
except Exception as e:
    print(f"下载模型时出错: {str(e)}")
    # 继续执行，不要因为下载失败而中断构建过程
    pass

# 创建配置文件
config = {
    "bucket_info": {},
    "models-dir": models_dir,
    "layoutreader-model-dir": layoutreader_dir,
    "device-mode": "cuda",
    "layout-config": {
        "model": "layoutlmv3"
    },
    "formula-config": {
        "mfd_model": "yolo_v8_mfd",
        "mfr_model": "unimernet_small",
        "enable": True
    },
    "table-config": {
        "model": "rapid_table",
        "enable": True,
        "max_time": 400
    },
    "config_version": "1.0.0"
}

# 保存配置文件
with open("/app/magic-pdf.json", "w") as f:
    json.dump(config, f, indent=4)

# 复制配置文件到其他位置
for config_path in ["/root/magic-pdf.json", os.path.join(os.path.expanduser("~"), "magic-pdf.json")]:
    try:
        os.makedirs(os.path.dirname(config_path), exist_ok=True)
        with open(config_path, "w") as f:
            json.dump(config, f, indent=4)
        print(f"配置文件已复制到: {config_path}")
    except Exception as e:
        print(f"复制配置文件到 {config_path} 时出错: {str(e)}")

print("配置文件已创建")

# 显示模型目录结构
print("模型目录结构：")
for root, dirs, files in os.walk(models_dir):
    for file in files:
        file_path = os.path.join(root, file)
        file_size = os.path.getsize(file_path)
        print(f"{file_path} ({file_size} bytes)") 