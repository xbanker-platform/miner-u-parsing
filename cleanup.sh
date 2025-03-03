#!/bin/bash

echo "清理 Docker 资源..."

# 停止所有运行中的容器
echo "停止所有容器..."
docker stop $(docker ps -a -q) 2>/dev/null || true

# 删除所有容器
echo "删除所有容器..."
docker rm $(docker ps -a -q) 2>/dev/null || true

# 删除 mineru 相关镜像
echo "删除 mineru 相关镜像..."
docker rmi $(docker images | grep mineru | awk '{print $3}') 2>/dev/null || true

# 删除未使用的卷
echo "删除未使用的卷..."
docker volume prune -f

# 删除未使用的网络
echo "删除未使用的网络..."
docker network prune -f

# 删除悬空镜像
echo "删除悬空镜像..."
docker image prune -f

echo "清理完成！" 