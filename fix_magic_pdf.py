#!/usr/bin/env python3
# 文件名: fix_magic_pdf.py
import os
import sys
import re
import json
import shutil

def patch_pdf_extract_kit():
    """修补 PDF Extract Kit 库，使其能够处理缺少配置的情况"""
    try:
        # 查找可能的路径
        possible_paths = [
            "/opt/mineru_venv/lib/python3.10/site-packages/magic_pdf/model/pdf_extract_kit.py",
            "/usr/local/lib/python3.10/site-packages/magic_pdf/model/pdf_extract_kit.py",
            # 添加其他可能的路径
        ]
        
        pdf_extract_kit_path = None
        for path in possible_paths:
            if os.path.exists(path):
                pdf_extract_kit_path = path
                break
        
        if not pdf_extract_kit_path:
            print("未找到 PDF Extract Kit 文件")
            return False
            
        print(f"找到 PDF Extract Kit 路径: {pdf_extract_kit_path}")
        
        # 创建备份
        backup_path = f"{pdf_extract_kit_path}.bak"
        if not os.path.exists(backup_path):
            shutil.copy2(pdf_extract_kit_path, backup_path)
            print(f"已创建备份: {backup_path}")
        
        # 读取文件内容
        with open(pdf_extract_kit_path, "r") as f:
            content = f.read()
        
        # 定义需要修改的模式和替换内容
        patterns = [
            # 模式 1: MFD 模型路径
            (r'models_dir, self\.configs\[[\'\"]weights[\'\"]\]\[self\.mfd_model_name\]', 
             r'models_dir, self.configs.get("weights", {}).get(self.mfd_model_name, f"MFD/YOLO/{self.mfd_model_name}.pt")'),
            
            # 模式 2: Layout 模型路径
            (r'models_dir, self\.configs\[[\'\"]weights[\'\"]\]\[self\.layout_model_name\]', 
             r'models_dir, self.configs.get("weights", {}).get(self.layout_model_name, f"Layout/YOLO/{self.layout_model_name}.pt")'),
            
            # 模式 3: MFR 模型路径
            (r'models_dir, self\.configs\[[\'\"]weights[\'\"]\]\[self\.mfr_model_name\]', 
             r'models_dir, self.configs.get("weights", {}).get(self.mfr_model_name, f"MFR/{self.mfr_model_name}.onnx")'),
            
            # 模式 4: Table 模型路径
            (r'self\.configs\[[\'\"]weights[\'\"]\]\[self\.table_model_name\]', 
             r'self.configs.get("weights", {}).get(self.table_model_name, f"TabRec/{self.table_model_name}")'),
        ]
        
        # 应用所有模式
        modified = False
        for pattern, replacement in patterns:
            if re.search(pattern, content):
                content = re.sub(pattern, replacement, content)
                modified = True
                print(f"应用模式: {pattern}")
        
        if modified:
            # 写回文件
            with open(pdf_extract_kit_path, "w") as f:
                f.write(content)
            print(f"已修补文件: {pdf_extract_kit_path}")
            return True
        else:
            print("未找到需要修补的代码")
            return False
    
    except Exception as e:
        print(f"修补 PDF Extract Kit 失败: {e}")
        return False

def ensure_config_file():
    """确保配置文件存在且格式正确"""
    try:
        config_path = "/root/magic-pdf.json"
        
        # 创建标准配置
        config = {
            "bucket_info": {
                "bucket-name-1": ["ak", "sk", "endpoint"],
                "bucket-name-2": ["ak", "sk", "endpoint"]
            },
            "models-dir": "/app/models",
            "layoutreader-model-dir": "/app/models/layoutreader",
            "device-mode": "cuda",
            "layout-config": {
                "model": "doclayout_yolo"
            },
            "formula-config": {
                "mfd_model": "yolo_v8_mfd",
                "mfr_model": "unimernet_small",
                "enable": True
            },
            "table-config": {
                "model": "rapid_table",
                "sub_model": "slanet_plus",
                "enable": True
            },
            "llm-aided-config": {
                "formula_aided": {
                    "api_key": "your_api_key",
                    "base_url": "https://dashscope.aliyuncs.com/compatible-mode/v1",
                    "model": "qwen2.5-7b-instruct",
                    "enable": False
                },
                "text_aided": {
                    "api_key": "your_api_key",
                    "base_url": "https://dashscope.aliyuncs.com/compatible-mode/v1",
                    "model": "qwen2.5-7b-instruct",
                    "enable": False
                },
                "title_aided": {
                    "api_key": "your_api_key",
                    "base_url": "https://dashscope.aliyuncs.com/compatible-mode/v1",
                    "model": "qwen2.5-32b-instruct",
                    "enable": False
                }
            },
            "config_version": "1.1.1",
            "weights": {
                "yolo_v8_mfd": "MFD/YOLO/yolo_v8_mfd.pt",
                "yolo_v8_ft": "MFD/YOLO/yolo_v8_ft.pt",
                "unimernet_small": "MFR/unimernet_small.onnx",
                "doclayout_yolo": "Layout/YOLO/doclayout_yolo.pt"
            }
        }
        
        # 如果配置文件存在，尝试读取并合并
        if os.path.exists(config_path):
            try:
                with open(config_path, "r") as f:
                    existing_config = json.load(f)
                
                # 确保weights部分包含所有必要的键
                if "weights" in existing_config:
                    for key, value in config["weights"].items():
                        if key not in existing_config["weights"]:
                            existing_config["weights"][key] = value
                else:
                    existing_config["weights"] = config["weights"]
                
                # 使用合并后的配置
                config = existing_config
                print("已合并现有配置文件")
            except json.JSONDecodeError:
                print("现有配置文件格式错误，将使用标准配置")
        
        # 写入配置文件
        with open(config_path, "w") as f:
            json.dump(config, f, indent=2)
        
        print(f"配置文件已更新: {config_path}")
        return True
    
    except Exception as e:
        print(f"更新配置文件失败: {e}")
        return False

def ensure_model_links():
    """确保模型文件和符号链接存在"""
    try:
        # 创建必要的目录
        os.makedirs("/app/models/MFD/YOLO", exist_ok=True)
        os.makedirs("/app/models/Layout/YOLO", exist_ok=True)
        os.makedirs("/app/models/MFR", exist_ok=True)
        os.makedirs("/app/models/TabRec", exist_ok=True)
        
        # 创建符号链接
        if os.path.exists("/app/models/MFD/YOLO/yolo_v8_mfd.pt"):
            if not os.path.exists("/app/models/MFD/YOLO/yolo_v8_ft.pt"):
                os.symlink("/app/models/MFD/YOLO/yolo_v8_mfd.pt", "/app/models/MFD/YOLO/yolo_v8_ft.pt")
                print("已创建符号链接: yolo_v8_mfd.pt -> yolo_v8_ft.pt")
        
        return True
    
    except Exception as e:
        print(f"确保模型链接失败: {e}")
        return False

def main():
    """主函数"""
    print("开始修复 MinerU...")
    
    # 确保配置文件存在
    if not ensure_config_file():
        print("警告: 配置文件可能不完整")
    
    # 确保模型链接存在
    if not ensure_model_links():
        print("警告: 模型链接可能不完整")
    
    # 修补 PDF Extract Kit
    if not patch_pdf_extract_kit():
        print("警告: PDF Extract Kit 修补可能不完整")
    
    print("修复完成!")
    return 0

if __name__ == "__main__":
    sys.exit(main())
