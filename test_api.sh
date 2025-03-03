#!/bin/bash

# 检查是否提供了PDF文件路径
if [ -z "$1" ]; then
    echo "用法: $0 <PDF文件路径>"
    exit 1
fi

PDF_FILE="$1"

# 检查文件是否存在
if [ ! -f "$PDF_FILE" ]; then
    echo "错误: 文件 '$PDF_FILE' 不存在"
    exit 1
fi

echo "正在处理PDF文件: $PDF_FILE"

# 使用curl发送请求
curl -X POST \
  http://localhost/process_pdf_and_return/ \
  -H "Content-Type: multipart/form-data" \
  -F "file=@$PDF_FILE" \
  -F "ocr=true" \
  -o result.json

echo "处理完成，结果保存在 result.json" 