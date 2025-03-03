import os
import json
from huggingface_hub import snapshot_download

# 设置模型目录
models_dir = '/models'
os.makedirs(models_dir, exist_ok=True)

try:
    # 下载 layoutlmv3 模型
    print('下载 layoutlmv3 模型...')
    layoutlmv3_dir = os.path.join(models_dir, 'layoutlmv3-base-chinese')
    os.makedirs(layoutlmv3_dir, exist_ok=True)
    
    snapshot_download(
        repo_id='opendatalab/layoutlmv3-base-chinese', 
        local_dir=layoutlmv3_dir,
        local_dir_use_symlinks=False,
        revision='main'
    )
    
    print('模型下载完成！')
    
    # 更新配置文件
    config_file = '/app/magic-pdf.json'
    with open(config_file, 'r') as f:
        config = json.load(f)
    
    # 确保配置正确
    config['layout-config']['model_path'] = layoutlmv3_dir
    
    with open(config_file, 'w') as f:
        json.dump(config, f, indent=4)
    
    # 复制配置文件到其他位置
    os.system('cp /app/magic-pdf.json /root/magic-pdf.json')
    
    print('配置文件已更新！')
    
except Exception as e:
    print(f'下载模型时出错: {str(e)}') 