#!/bin/bash
# 文件名: stop.sh

# 显示欢迎信息
echo "=== MinerU 停止脚本 ==="

# 停止容器
echo "停止容器..."
docker-compose down || docker compose down

echo "=== MinerU 已停止 ==="
