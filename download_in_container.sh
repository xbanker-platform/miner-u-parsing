#!/bin/bash

echo "在Docker容器内部下载LayoutLMv3模型文件..."

# 在容器内部执行下载命令
docker exec -it mineru-service bash -c "
echo '开始在容器内部下载模型文件...'

# 确保目录存在
mkdir -p /models/layoutlmv3-base-chinese

# 下载config.json
echo '下载config.json...'
curl -L https://huggingface.co/opendatalab/layoutlmv3-base-chinese/resolve/main/config.json -o /models/layoutlmv3-base-chinese/config.json

# 检查文件是否下载成功
if [ ! -s '/models/layoutlmv3-base-chinese/config.json' ]; then
    echo '错误: config.json 下载失败或文件为空！'
else
    echo 'config.json 下载成功！'
    ls -la /models/layoutlmv3-base-chinese/config.json
fi

# 下载pytorch_model.bin（这个文件可能很大）
echo '下载pytorch_model.bin（这可能需要一些时间）...'
curl -L https://huggingface.co/opendatalab/layoutlmv3-base-chinese/resolve/main/pytorch_model.bin -o /models/layoutlmv3-base-chinese/pytorch_model.bin

# 检查文件是否下载成功
if [ ! -s '/models/layoutlmv3-base-chinese/pytorch_model.bin' ]; then
    echo '错误: pytorch_model.bin 下载失败或文件为空！'
else
    echo 'pytorch_model.bin 下载成功！'
    ls -la /models/layoutlmv3-base-chinese/pytorch_model.bin
fi

# 尝试使用Python脚本下载
echo '尝试使用Python脚本下载模型...'
python3 -c '
import os
from huggingface_hub import snapshot_download

# 设置模型目录
models_dir = \"/models\"
os.makedirs(os.path.join(models_dir, \"layoutlmv3-base-chinese\"), exist_ok=True)

try:
    # 下载 layoutlmv3 模型
    print(\"下载 layoutlmv3 模型...\")
    snapshot_download(
        repo_id=\"opendatalab/layoutlmv3-base-chinese\", 
        local_dir=os.path.join(models_dir, \"layoutlmv3-base-chinese\"),
        local_dir_use_symlinks=False,
        revision=\"main\"
    )
    print(\"模型下载完成！\")
except Exception as e:
    print(f\"下载模型时出错: {str(e)}\")
'
"

echo "重启容器以应用更改..."
docker restart mineru-service

echo "完成！" 