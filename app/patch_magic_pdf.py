#!/usr/bin/env python3
# 文件名: app/patch_magic_pdf.py
"""
MagicPDF 补丁文件 - 在不修改原始代码的情况下修复 KeyError 问题
"""
import os
import sys
import importlib
import types
import json

# 原始的 CustomPEKModel.__init__ 方法
original_init = None

def patched_init(self, ocr=False, show_log=False, **kwargs):
    """
    CustomPEKModel.__init__ 的补丁版本，处理缺少配置的情况
    """
    # 确保配置文件存在
    ensure_config_file()
    
    # 调用原始的 __init__ 方法
    try:
        original_init(self, ocr, show_log, **kwargs)
    except KeyError as e:
        # 捕获 KeyError 并提供默认值
        if str(e).strip("'") == "yolo_v8_ft" or str(e).strip("'") == "yolo_v8_mfd":
            # 获取模型目录
            models_dir = kwargs.get(
                'models_dir', 
                os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), 'resources', 'models')
            )
            
            # 创建必要的目录
            os.makedirs(os.path.join(models_dir, "MFD/YOLO"), exist_ok=True)
            
            # 创建符号链接
            mfd_path = os.path.join(models_dir, "MFD/YOLO/yolo_v8_mfd.pt")
            ft_path = os.path.join(models_dir, "MFD/YOLO/yolo_v8_ft.pt")
            
            if os.path.exists(mfd_path) and not os.path.exists(ft_path):
                try:
                    os.symlink(mfd_path, ft_path)
                    print(f"已创建符号链接: {mfd_path} -> {ft_path}")
                except Exception as link_err:
                    print(f"创建符号链接失败: {link_err}")
            
            # 重试初始化
            print(f"捕获到 KeyError: {e}，尝试使用默认配置重新初始化...")
            
            # 修改 self.configs 添加缺失的配置
            if not hasattr(self, 'configs'):
                self.configs = {}
            
            if 'weights' not in self.configs:
                self.configs['weights'] = {}
            
            self.configs['weights']['yolo_v8_mfd'] = "MFD/YOLO/yolo_v8_mfd.pt"
            self.configs['weights']['yolo_v8_ft'] = "MFD/YOLO/yolo_v8_ft.pt"
            self.configs['weights']['unimernet_small'] = "MFR/unimernet_small.onnx"
            self.configs['weights']['doclayout_yolo'] = "Layout/YOLO/doclayout_yolo.pt"
            
            # 重新调用原始方法
            try:
                original_init(self, ocr, show_log, **kwargs)
                print("使用修补后的配置重新初始化成功")
            except Exception as retry_err:
                print(f"重新初始化失败: {retry_err}")
                raise
        else:
            # 其他 KeyError，重新抛出
            raise

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

def apply_patch():
    """应用补丁到 magic_pdf 模块"""
    try:
        # 导入 magic_pdf 模块
        import magic_pdf.model.pdf_extract_kit
        
        # 保存原始的 __init__ 方法
        global original_init
        original_init = magic_pdf.model.pdf_extract_kit.CustomPEKModel.__init__
        
        # 替换为我们的补丁版本
        magic_pdf.model.pdf_extract_kit.CustomPEKModel.__init__ = patched_init
        
        print("已成功应用 MagicPDF 补丁")
        return True
    except ImportError:
        print("无法导入 magic_pdf 模块，补丁未应用")
        return False
    except Exception as e:
        print(f"应用补丁时出错: {e}")
        return False

# 自动应用补丁
apply_patch() 