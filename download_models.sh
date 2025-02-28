#!/bin/bash

# 安装huggingface_hub
pip install huggingface_hub

# 下载模型下载脚本
wget https://github.com/opendatalab/MinerU/raw/master/scripts/download_models_hf.py -O download_models_hf.py

# 执行下载
python3 download_models_hf.py

# 创建模型目录
mkdir -p models

# 复制模型文件到models目录
cp -r ~/magic-pdf-models/* models/

echo "Models downloaded successfully to ./models directory" 