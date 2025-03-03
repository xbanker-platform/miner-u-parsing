# MinerU Docker 部署

这是 MinerU 项目的 Docker 部署方案，提供了一键部署脚本，方便快速搭建 PDF 处理服务。

## 系统要求

- Ubuntu 22.04 LTS 或更高版本
- NVIDIA GPU（至少 8GB 显存）
- NVIDIA 驱动（支持 CUDA 12.1 或更高版本）
- Docker 和 Docker Compose
- 至少 10GB 可用磁盘空间

## 快速开始

1. 确保已安装 Docker 和 NVIDIA 驱动：

```bash
# 检查 Docker 是否安装
docker --version

# 检查 NVIDIA 驱动是否安装
nvidia-smi
```

2. 克隆本仓库：

```bash
git clone <repository-url> mineru-docker
cd mineru-docker
```

3. 运行一键部署脚本：

```bash
chmod +x deploy.sh
./deploy.sh
```

4. 部署完成后，服务将在 http://localhost:8000 上运行。

## 目录结构

```
mineru-docker/
├── app/                # 应用程序代码
│   └── start_app.sh    # 容器内启动脚本
├── config/             # 配置文件
├── data/               # 数据目录
├── models/             # 模型文件目录
├── output/             # 输出目录
├── uploads/            # 上传文件目录
├── scripts/            # 辅助脚本
├── cleanup.sh          # 清理脚本
├── deploy.sh           # 一键部署脚本
├── docker-compose.yml  # Docker Compose 配置
├── Dockerfile          # Docker 构建文件
└── nginx.conf          # Nginx 配置
```

## 使用方法

### 启动服务

```bash
docker compose up -d
```

### 查看日志

```bash
docker compose logs -f mineru
```

### 停止服务

```bash
docker compose down
```

### 清理资源

```bash
./cleanup.sh
```

## API 使用示例

### 上传并处理 PDF

```bash
curl -X POST -F "file=@example.pdf" http://localhost:8000/upload_and_process_pdf/
```

### 获取处理结果

```bash
curl -X GET http://localhost:8000/get_results/{task_id}
```

## 故障排除

如果遇到问题，请检查以下几点：

1. 确保 NVIDIA 驱动正确安装并支持 CUDA 12.1
2. 确保 Docker 和 Docker Compose 已正确安装
3. 检查模型文件是否正确下载
4. 查看容器日志以获取详细错误信息

## 许可证

本项目基于 [MinerU](https://github.com/opendatalab/MinerU) 开发，请遵循原项目的许可证要求。 