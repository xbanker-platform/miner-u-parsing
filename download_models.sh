#!/bin/bash

# 显示彩色输出
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${GREEN}===== MinerU 模型下载脚本 =====${NC}"

# 创建必要的目录
echo -e "${YELLOW}创建必要的目录...${NC}"
mkdir -p models/MFD/YOLO models/layoutlmv3-base-chinese models/layoutreader models/rapid_table models/unimernet_small models/yolo_v8_mfd

# 下载 yolo_v8_mfd.pt 模型
echo -e "${YELLOW}下载 yolo_v8_mfd.pt 模型...${NC}"
if [ ! -f "models/MFD/YOLO/yolo_v8_mfd.pt" ]; then
    wget -q --show-progress https://huggingface.co/opendatalab/yolo_v8_mfd/resolve/main/yolo_v8_mfd.pt -O models/MFD/YOLO/yolo_v8_mfd.pt
    if [ $? -ne 0 ]; then
        echo -e "${RED}下载 yolo_v8_mfd.pt 失败！${NC}"
        exit 1
    fi
else
    echo -e "${GREEN}yolo_v8_mfd.pt 已存在，跳过下载${NC}"
fi

# 创建 yolo_v8_ft.pt 文件（复制 yolo_v8_mfd.pt）
echo -e "${YELLOW}创建 yolo_v8_ft.pt 文件...${NC}"
if [ ! -f "models/MFD/YOLO/yolo_v8_ft.pt" ]; then
    if [ -f "models/MFD/YOLO/yolo_v8_mfd.pt" ]; then
        cp models/MFD/YOLO/yolo_v8_mfd.pt models/MFD/YOLO/yolo_v8_ft.pt
        echo -e "${GREEN}yolo_v8_ft.pt 已创建${NC}"
    else
        echo -e "${RED}无法创建 yolo_v8_ft.pt，源文件不存在！${NC}"
        exit 1
    fi
else
    echo -e "${GREEN}yolo_v8_ft.pt 已存在，跳过创建${NC}"
fi

# 下载其他可选模型
echo -e "${YELLOW}是否下载其他可选模型？这可能需要较长时间。(y/n)${NC}"
read -p "请输入 y 或 n: " download_others

if [ "$download_others" = "y" ]; then
    # 下载 layoutlmv3-base-chinese 模型
    echo -e "${YELLOW}下载 layoutlmv3-base-chinese 模型...${NC}"
    if [ ! -f "models/layoutlmv3-base-chinese/pytorch_model.bin" ]; then
        mkdir -p models/layoutlmv3-base-chinese
        wget -q --show-progress https://huggingface.co/opendatalab/layoutlmv3-base-chinese/resolve/main/pytorch_model.bin -O models/layoutlmv3-base-chinese/pytorch_model.bin
    else
        echo -e "${GREEN}layoutlmv3-base-chinese 模型已存在，跳过下载${NC}"
    fi
    
    # 下载 rapid_table 模型
    echo -e "${YELLOW}下载 rapid_table 模型...${NC}"
    if [ ! -d "models/rapid_table/model.onnx" ]; then
        mkdir -p models/rapid_table
        wget -q --show-progress https://huggingface.co/opendatalab/rapid_table/resolve/main/model.onnx -O models/rapid_table/model.onnx
    else
        echo -e "${GREEN}rapid_table 模型已存在，跳过下载${NC}"
    fi
    
    # 下载 unimernet_small 模型
    echo -e "${YELLOW}下载 unimernet_small 模型...${NC}"
    if [ ! -d "models/unimernet_small/model.onnx" ]; then
        mkdir -p models/unimernet_small
        wget -q --show-progress https://huggingface.co/opendatalab/unimernet_small/resolve/main/model.onnx -O models/unimernet_small/model.onnx
    else
        echo -e "${GREEN}unimernet_small 模型已存在，跳过下载${NC}"
    fi
else
    echo -e "${YELLOW}跳过下载其他可选模型${NC}"
fi

# 显示模型目录结构
echo -e "${YELLOW}模型目录结构：${NC}"
find models -type f | sort

echo -e "${GREEN}模型下载完成！${NC}" 