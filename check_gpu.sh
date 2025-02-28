#!/bin/bash

# 进入容器并检查GPU状态
docker exec -it mineru-docker-mineru-1 bash -c "source /opt/mineru_venv/bin/activate && python -c 'import torch; print(\"CUDA available:\", torch.cuda.is_available()); print(\"GPU count:\", torch.cuda.device_count()); print(\"GPU name:\", torch.cuda.get_device_name(0) if torch.cuda.is_available() else \"None\")'"

# 检查nvidia-smi
docker exec -it mineru-docker-mineru-1 nvidia-smi 