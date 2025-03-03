#!/bin/bash

echo "开始下载LayoutLMv3模型文件..."

# 创建目录
mkdir -p models/layoutlmv3-base-chinese

# 下载config.json
echo "下载config.json..."
curl -L https://huggingface.co/opendatalab/layoutlmv3-base-chinese/resolve/main/config.json -o models/layoutlmv3-base-chinese/config.json

# 检查文件是否下载成功
if [ ! -s "models/layoutlmv3-base-chinese/config.json" ]; then
    echo "错误: config.json 下载失败或文件为空！"
    exit 1
else
    echo "config.json 下载成功！"
    ls -la models/layoutlmv3-base-chinese/config.json
fi

# 下载pytorch_model.bin（这个文件可能很大）
echo "下载pytorch_model.bin（这可能需要一些时间）..."
curl -L https://huggingface.co/opendatalab/layoutlmv3-base-chinese/resolve/main/pytorch_model.bin -o models/layoutlmv3-base-chinese/pytorch_model.bin

# 检查文件是否下载成功
if [ ! -s "models/layoutlmv3-base-chinese/pytorch_model.bin" ]; then
    echo "错误: pytorch_model.bin 下载失败或文件为空！"
    exit 1
else
    echo "pytorch_model.bin 下载成功！"
    ls -la models/layoutlmv3-base-chinese/pytorch_model.bin
fi

# 复制文件到Docker容器
echo "复制文件到Docker容器..."
docker cp models/layoutlmv3-base-chinese/config.json mineru-service:/models/layoutlmv3-base-chinese/
docker cp models/layoutlmv3-base-chinese/pytorch_model.bin mineru-service:/models/layoutlmv3-base-chinese/

echo "重启容器以应用更改..."
docker restart mineru-service

echo "完成！" 