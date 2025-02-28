#!/bin/bash
source /opt/mineru_venv/bin/activate

# 运行初始化脚本
/app/scripts/download_models.sh
/app/scripts/copy_models.sh

# 运行测试
python3 /app/tests/test_config.py

# 启动应用
exec "$@" 