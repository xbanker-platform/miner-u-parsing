#!/bin/bash

# 显示彩色输出
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${GREEN}===== MinerU 环境检查脚本 =====${NC}"

# 检查操作系统
echo -e "${YELLOW}检查操作系统...${NC}"
OS=$(cat /etc/os-release | grep "PRETTY_NAME" | cut -d'"' -f2)
echo -e "操作系统: ${GREEN}$OS${NC}"

# 检查 Docker 是否安装
echo -e "${YELLOW}检查 Docker...${NC}"
if command -v docker &> /dev/null; then
    DOCKER_VERSION=$(docker --version)
    echo -e "Docker: ${GREEN}已安装 - $DOCKER_VERSION${NC}"
else
    echo -e "Docker: ${RED}未安装${NC}"
    echo -e "${YELLOW}请安装 Docker: https://docs.docker.com/engine/install/${NC}"
fi

# 检查 Docker Compose 是否安装
echo -e "${YELLOW}检查 Docker Compose...${NC}"
if docker compose version &> /dev/null; then
    COMPOSE_VERSION=$(docker compose version)
    echo -e "Docker Compose: ${GREEN}已安装 - $COMPOSE_VERSION${NC}"
else
    echo -e "Docker Compose: ${RED}未安装${NC}"
    echo -e "${YELLOW}请安装 Docker Compose: https://docs.docker.com/compose/install/${NC}"
fi

# 检查 NVIDIA 驱动
echo -e "${YELLOW}检查 NVIDIA 驱动...${NC}"
if command -v nvidia-smi &> /dev/null; then
    NVIDIA_INFO=$(nvidia-smi --query-gpu=name,driver_version,memory.total --format=csv,noheader)
    echo -e "NVIDIA 驱动: ${GREEN}已安装${NC}"
    echo -e "$NVIDIA_INFO"
    
    # 检查 CUDA 版本
    CUDA_VERSION=$(nvidia-smi | grep "CUDA Version" | awk '{print $9}')
    if [[ $(echo "$CUDA_VERSION >= 12.1" | bc -l) -eq 1 ]]; then
        echo -e "CUDA 版本: ${GREEN}$CUDA_VERSION (满足要求)${NC}"
    else
        echo -e "CUDA 版本: ${YELLOW}$CUDA_VERSION (建议 >= 12.1)${NC}"
    fi
    
    # 检查显存大小
    MEMORY_TOTAL=$(echo "$NVIDIA_INFO" | awk -F', ' '{print $3}' | awk '{print $1}')
    if [[ $(echo "$MEMORY_TOTAL >= 8000" | bc -l) -eq 1 ]]; then
        echo -e "显存大小: ${GREEN}${MEMORY_TOTAL} MiB (满足要求)${NC}"
    else
        echo -e "显存大小: ${YELLOW}${MEMORY_TOTAL} MiB (建议 >= 8000 MiB)${NC}"
    fi
else
    echo -e "NVIDIA 驱动: ${RED}未安装${NC}"
    echo -e "${YELLOW}请安装 NVIDIA 驱动: https://www.nvidia.com/Download/index.aspx${NC}"
fi

# 检查磁盘空间
echo -e "${YELLOW}检查磁盘空间...${NC}"
DISK_SPACE=$(df -h . | awk 'NR==2 {print $4}')
echo -e "可用磁盘空间: ${GREEN}$DISK_SPACE${NC}"

# 检查网络连接
echo -e "${YELLOW}检查网络连接...${NC}"
if ping -c 1 huggingface.co &> /dev/null; then
    echo -e "Hugging Face 连接: ${GREEN}正常${NC}"
else
    echo -e "Hugging Face 连接: ${RED}异常${NC}"
    echo -e "${YELLOW}请检查网络连接，确保可以访问 huggingface.co${NC}"
fi

# 总结
echo -e "\n${GREEN}===== 环境检查完成 =====${NC}"
echo -e "${YELLOW}如果所有检查都通过，您可以运行以下命令开始部署：${NC}"
echo -e "${GREEN}chmod +x deploy.sh${NC}"
echo -e "${GREEN}./deploy.sh${NC}" 