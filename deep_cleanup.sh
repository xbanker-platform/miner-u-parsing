#!/bin/bash

echo "开始深度清理Docker资源..."

# 停止所有运行中的容器
echo "停止所有容器..."
docker stop $(docker ps -a -q) 2>/dev/null || true

# 删除所有容器
echo "删除所有容器..."
docker rm $(docker ps -a -q) 2>/dev/null || true

# 删除所有镜像
echo "删除所有镜像..."
docker rmi $(docker images -q) 2>/dev/null || true

# 删除所有卷
echo "删除所有卷..."
docker volume rm $(docker volume ls -q) 2>/dev/null || true

# 删除所有网络
echo "删除所有自定义网络..."
docker network rm $(docker network ls | grep -v "bridge\|host\|none" | awk '{print $1}') 2>/dev/null || true

# 清理系统
echo "清理系统..."
docker system prune -a -f --volumes

echo "Docker资源已完全清理！" 