# MagicPDF 补丁 - 直接在 app.py 中修复 KeyError 问题
import os
import sys
import json

def patch_magic_pdf():
    """直接修补 magic_pdf 模块"""
    try:
        # 导入 magic_pdf 模块
        import magic_pdf.model.pdf_extract_kit
        
        # 保存原始的 __init__ 方法
        original_init = magic_pdf.model.pdf_extract_kit.CustomPEKModel.__init__
        
        # 定义补丁版本的 __init__ 方法
        def patched_init(self, ocr=False, show_log=False, **kwargs):
            """处理缺少配置的情况"""
            # 确保配置文件存在
            ensure_config_file()
            
            # 创建必要的目录
            models_dir = kwargs.get('models_dir', '/app/models')
            os.makedirs(os.path.join(models_dir, "MFD/YOLO"), exist_ok=True)
            os.makedirs(os.path.join(models_dir, "Layout/YOLO"), exist_ok=True)
            os.makedirs(os.path.join(models_dir, "MFR"), exist_ok=True)
            
            # 创建符号链接
            mfd_path = os.path.join(models_dir, "MFD/YOLO/yolo_v8_mfd.pt")
            ft_path = os.path.join(models_dir, "MFD/YOLO/yolo_v8_ft.pt")
            
            if os.path.exists(mfd_path) and not os.path.exists(ft_path):
                try:
                    os.symlink(mfd_path, ft_path)
                    print(f"已创建符号链接: {mfd_path} -> {ft_path}")
                except Exception as link_err:
                    print(f"创建符号链接失败: {link_err}")
            
            # 调用原始的 __init__ 方法
            try:
                original_init(self, ocr, show_log, **kwargs)
            except KeyError as e:
                # 捕获 KeyError 并提供默认值
                if str(e).strip("'") == "yolo_v8_ft" or str(e).strip("'") == "yolo_v8_mfd":
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

# 应用补丁
patch_magic_pdf()

from fastapi import FastAPI, UploadFile, File, BackgroundTasks, HTTPException
from fastapi.responses import JSONResponse, FileResponse
from fastapi.middleware.cors import CORSMiddleware
import tempfile
import os
import subprocess
import shutil
import uuid
import logging
from typing import Dict, Optional, List
import json
from datetime import datetime, timedelta
from concurrent.futures import ThreadPoolExecutor
import asyncio
from starlette.middleware.base import BaseHTTPMiddleware
import traceback

# 配置日志
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.StreamHandler(),
        logging.FileHandler("mineru_api.log")
    ]
)
logger = logging.getLogger("mineru-api")

# 创建数据目录
os.makedirs("/data/results", exist_ok=True)
os.makedirs("/data/uploads", exist_ok=True)

app = FastAPI(title="MinerU API", description="API for processing PDF documents with MinerU")

# 添加CORS中间件
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # 在生产环境中应该限制来源
    allow_credentials=True,
    allow_methods=["GET", "POST", "DELETE"],
    allow_headers=["*"],
)

# 创建线程池处理PDF任务
pdf_executor = ThreadPoolExecutor(max_workers=4)  # 增加工作线程数

# 添加超时设置
PROCESS_TIMEOUT = 300  # 5分钟超时
REQUEST_TIMEOUT = 60   # 1分钟请求超时

# 存储任务状态和结果
class TaskResult:
    def __init__(self):
        self.status = "pending"
        self.markdown = None
        self.content_list = None
        self.middle_json = None
        self.error = None
        self.created_at = datetime.now()
        self.processing_time = None  # 添加处理时间记录
        self.filename = None
        self.file_path = None

task_results: Dict[str, TaskResult] = {}

class ErrorHandlingMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request, call_next):
        try:
            response = await call_next(request)
            return response
        except Exception as e:
            logger.error(f"Unhandled error: {str(e)}\n{traceback.format_exc()}")
            return JSONResponse(
                status_code=500,
                content={
                    "detail": "Internal server error",
                    "error": str(e)
                }
            )

app.add_middleware(ErrorHandlingMiddleware)

@app.post("/upload_and_process_pdf/")
async def upload_and_process_pdf(
    background_tasks: BackgroundTasks,
    file: UploadFile = File(...),
    ocr: bool = True
):
    try:
        # 上传文件
        task_id = str(uuid.uuid4())
        task_dir = f"/data/uploads/{task_id}"
        output_dir = f"/data/results/{task_id}"
        os.makedirs(task_dir, exist_ok=True)
        os.makedirs(output_dir, exist_ok=True)
        os.makedirs(f"{output_dir}/images", exist_ok=True)
        
        # 保存文件
        file_path = os.path.join(task_dir, file.filename)
        with open(file_path, "wb") as buffer:
            chunk_size = 4 * 1024 * 1024
            while True:
                chunk = await file.read(chunk_size)
                if not chunk:
                    break
                buffer.write(chunk)
        
        # 记录任务
        task_results[task_id] = TaskResult()
        task_results[task_id].status = "processing"
        task_results[task_id].filename = file.filename
        task_results[task_id].file_path = file_path
        
        # 在后台处理PDF
        background_tasks.add_task(
            process_pdf_background, 
            task_id, 
            file_path, 
            output_dir, 
            ocr,
            file.filename
        )
        
        return {
            "task_id": task_id,
            "status": "processing",
            "message": "PDF uploaded and processing started"
        }
    except Exception as e:
        logger.error(f"Error uploading and processing PDF: {str(e)}", exc_info=True)
        raise HTTPException(
            status_code=500,
            detail=f"Error uploading and processing PDF: {str(e)}"
        )

@app.post("/process_task/{task_id}")
async def process_task(
    task_id: str,
    background_tasks: BackgroundTasks,
    ocr: bool = True
):
    if task_id not in task_results:
        raise HTTPException(status_code=404, detail="Task not found")
    
    task = task_results[task_id]
    if task.status != "uploaded":
        return {
            "task_id": task_id,
            "status": task.status,
            "message": f"Task is already in {task.status} state"
        }
    
    # 创建输出目录
    output_dir = f"/data/results/{task_id}"
    os.makedirs(output_dir, exist_ok=True)
    os.makedirs(f"{output_dir}/images", exist_ok=True)
    
    # 更新任务状态
    task.status = "processing"
    
    # 在后台处理PDF
    background_tasks.add_task(
        process_pdf_background, 
        task_id, 
        task.file_path, 
        output_dir, 
        ocr,
        task.filename
    )
    
    return {
        "task_id": task_id,
        "status": "processing",
        "message": "PDF processing started"
    }

async def process_pdf_background(task_id: str, file_path: str, output_dir: str, ocr: bool, filename: str):
    try:
        task_results[task_id].status = "processing"
        start_time = datetime.now()
        
        # 使用线程池执行PDF处理，添加超时
        loop = asyncio.get_event_loop()
        try:
            await asyncio.wait_for(
                loop.run_in_executor(pdf_executor, process_pdf_task, task_id, file_path, output_dir, ocr),
                timeout=PROCESS_TIMEOUT
            )
        except asyncio.TimeoutError:
            task_results[task_id].status = "failed"
            task_results[task_id].error = "Processing timeout after 5 minutes"
            return
            
        task_results[task_id].processing_time = (datetime.now() - start_time).total_seconds()
        
    except Exception as e:
        logger.error(f"Error processing PDF: {str(e)}", exc_info=True)
        task_results[task_id].status = "failed"
        task_results[task_id].error = str(e)

def process_pdf_task(task_id: str, file_path: str, output_dir: str, ocr: bool):
    try:
        # 使用Python API处理PDF
        logger.info(f"Processing PDF: {file_path} with OCR={ocr}")
        
        # 创建Python脚本
        script_path = os.path.join("/data/uploads", f"{task_id}_process.py")
        with open(script_path, "w") as f:
            f.write(f"""
import os
from magic_pdf.data.data_reader_writer import FileBasedDataWriter, FileBasedDataReader
from magic_pdf.data.dataset import PymuDocDataset
from magic_pdf.model.doc_analyze_by_custom_model import doc_analyze
from magic_pdf.config.enums import SupportedPdfParseMethod

# args
pdf_file_name = "{file_path}"
name_without_suff = os.path.basename(pdf_file_name).split(".")[0]

# prepare env
local_image_dir, local_md_dir = "{output_dir}/images", "{output_dir}"
image_dir = "images"

# read bytes
reader1 = FileBasedDataReader("")
pdf_bytes = reader1.read(pdf_file_name)

# Create image writer and md writer
image_writer = FileBasedDataWriter(local_image_dir)
md_writer = FileBasedDataWriter(local_md_dir)

# proc
## Create Dataset Instance
ds = PymuDocDataset(pdf_bytes)

## inference
if ds.classify() == SupportedPdfParseMethod.OCR or {ocr}:
    infer_result = ds.apply(doc_analyze, ocr=True)
    ## pipeline
    pipe_result = infer_result.pipe_ocr_mode(image_writer)
else:
    infer_result = ds.apply(doc_analyze, ocr=False)
    ## pipeline
    pipe_result = infer_result.pipe_txt_mode(image_writer)

### get markdown content
md_content = pipe_result.get_markdown(image_dir)

### dump markdown
pipe_result.dump_md(md_writer, f"{{name_without_suff}}.md", image_dir)

### get content list content
content_list_content = pipe_result.get_content_list(image_dir)

### dump content list
pipe_result.dump_content_list(md_writer, f"{{name_without_suff}}_content_list.json", image_dir)

### get middle json
middle_json_content = pipe_result.get_middle_json()

### dump middle json
pipe_result.dump_middle_json(md_writer, f'{{name_without_suff}}_middle.json')

print("Processing completed successfully!")
""")
        
        # 执行Python脚本
        cmd = [
            "/bin/bash", 
            "-c", 
            f"source /opt/mineru_venv/bin/activate && python {script_path}"
        ]
        
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True
        )
        
        # 检查命令是否成功
        if result.returncode != 0:
            logger.error(f"Command failed: {result.stderr}")
            task_results[task_id].status = "failed"
            task_results[task_id].error = result.stderr
            return
        
        # 读取处理结果并存储在内存中
        base_name = os.path.splitext(os.path.basename(file_path))[0]
        
        with open(f"{output_dir}/{base_name}.md", 'r', encoding='utf-8') as f:
            task_results[task_id].markdown = f.read()
            
        with open(f"{output_dir}/{base_name}_content_list.json", 'r', encoding='utf-8') as f:
            task_results[task_id].content_list = f.read()
            
        with open(f"{output_dir}/{base_name}_middle.json", 'r', encoding='utf-8') as f:
            task_results[task_id].middle_json = f.read()
        
        task_results[task_id].status = "completed"
        
        # 清理临时文件
        shutil.rmtree(output_dir, ignore_errors=True)
        os.remove(file_path)
        
    except Exception as e:
        logger.error(f"Error in PDF task: {str(e)}", exc_info=True)
        task_results[task_id].status = "failed"
        task_results[task_id].error = str(e)

@app.get("/tasks/{task_id}")
async def get_task_status(task_id: str):
    if task_id not in task_results:
        raise HTTPException(status_code=404, detail="Task not found")
    
    return task_results[task_id].__dict__

@app.get("/tasks")
async def list_tasks():
    return list(task_results.values())

@app.get("/download/{task_id}/{file_path:path}")
async def download_file(task_id: str, file_path: str):
    if task_id not in task_results:
        raise HTTPException(status_code=404, detail="Task not found")
    
    task = task_results[task_id]
    file_full_path = os.path.join(task["output_dir"], file_path)
    
    if not os.path.exists(file_full_path):
        raise HTTPException(status_code=404, detail="File not found")
    
    return FileResponse(file_full_path)

@app.delete("/tasks/{task_id}")
async def delete_task(task_id: str):
    if task_id not in task_results:
        raise HTTPException(status_code=404, detail="Task not found")
    
    # 删除任务文件
    task = task_results[task_id]
    shutil.rmtree(f"/data/uploads/{task_id}", ignore_errors=True)
    shutil.rmtree(task["output_dir"], ignore_errors=True)
    
    # 删除任务记录
    del task_results[task_id]
    
    return {"message": "Task deleted successfully"}

@app.get("/health")
async def health_check():
    try:
        # 检查GPU状态
        gpu_result = subprocess.run(
            ["nvidia-smi"], 
            capture_output=True,
            text=True,
            timeout=5  # 添加超时
        )
        gpu_available = gpu_result.returncode == 0
        
        # 检查系统状态
        active_tasks = len([t for t in task_results.values() if t.status == "processing"])
        
        return {
            "status": "healthy",
            "gpu_available": gpu_available,
            "active_tasks": active_tasks,
            "worker_pool_size": pdf_executor._max_workers,
            "timestamp": datetime.now().isoformat()
        }
    except Exception as e:
        logger.error(f"Health check failed: {str(e)}", exc_info=True)
        return {
            "status": "unhealthy",
            "error": str(e),
            "timestamp": datetime.now().isoformat()
        }

@app.get("/")
async def root():
    return {"message": "MinerU API is running. Visit /docs for API documentation."}

@app.get("/get_results/{task_id}")
async def get_results(task_id: str):
    if task_id not in task_results:
        raise HTTPException(status_code=404, detail="Task not found")
    
    task = task_results[task_id]
    if task["status"] != "completed":
        return {
            "status": task["status"],
            "message": "Task is still processing"
        }
    
    base_name = os.path.splitext(task["filename"])[0]
    result_files = {
        "markdown": f"{base_name}.md",
        "content_list": f"{base_name}_content_list.json",
        "middle_json": f"{base_name}_middle.json"
    }
    
    results = {}
    for key, filename in result_files.items():
        file_path = os.path.join(task["output_dir"], filename)
        if os.path.exists(file_path):
            with open(file_path, 'r', encoding='utf-8') as f:
                results[key] = f.read()
    
    return JSONResponse(content=results)

@app.get("/get_markdown/{task_id}")
async def get_markdown(task_id: str):
    try:
        if task_id not in task_results:
            raise HTTPException(status_code=404, detail="Task not found")
        
        result = task_results[task_id]
        
        # 检查任务状态
        if result.status == "failed":
            raise HTTPException(status_code=500, detail=result.error)
        elif result.status == "processing":
            return JSONResponse(
                status_code=202,  # 使用202 Accepted表示正在处理
                content={
                    "status": "processing",
                    "message": "Task is still processing",
                    "processing_time": result.processing_time
                }
            )
        elif result.status == "completed":
            if result.markdown is None:
                raise HTTPException(status_code=500, detail="Markdown content not found")
            
            return JSONResponse(
                content={
                    "status": "completed",
                    "markdown": result.markdown,
                    "processing_time": result.processing_time
                }
            )
        else:
            raise HTTPException(status_code=500, detail=f"Unknown task status: {result.status}")
            
    except Exception as e:
        logger.error(f"Error getting markdown for task {task_id}: {str(e)}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/get_content_list/{task_id}")
async def get_content_list(task_id: str):
    if task_id not in task_results:
        raise HTTPException(status_code=404, detail="Task not found")
    
    result = task_results[task_id]
    if result.status == "failed":
        raise HTTPException(status_code=500, detail=result.error)
    elif result.status == "processing":
        return {"status": "processing", "message": "Task is still processing"}
    
    return JSONResponse(content={"content_list": result.content_list})

@app.get("/get_middle_json/{task_id}")
async def get_middle_json(task_id: str):
    if task_id not in task_results:
        raise HTTPException(status_code=404, detail="Task not found")
    
    result = task_results[task_id]
    if result.status == "failed":
        raise HTTPException(status_code=500, detail=result.error)
    elif result.status == "processing":
        return {"status": "processing", "message": "Task is still processing"}
    
    return JSONResponse(content={"middle_json": result.middle_json})

# 添加任务恢复函数
async def recover_hanging_tasks():
    while True:
        try:
            current_time = datetime.now()
            for task_id, task in task_results.items():
                # 如果任务处理时间超过10分钟，标记为失败
                if (task.status == "processing" and 
                    (current_time - task.created_at).total_seconds() > 600):
                    task.status = "failed"
                    task.error = "Task recovery: Processing timeout"
                    logger.warning(f"Recovered hanging task: {task_id}")
            
            await asyncio.sleep(60)  # 每分钟检查一次
            
        except Exception as e:
            logger.error(f"Error in task recovery: {str(e)}")
            await asyncio.sleep(60)

# 在应用启动时运行恢复程序
@app.on_event("startup")
async def startup_event():
    # 创建或修改magic-pdf.json配置文件以启用CUDA
    config_path = os.path.expanduser("~/magic-pdf.json")
    
    # 如果配置文件存在，读取它
    if os.path.exists(config_path):
        with open(config_path, "r") as f:
            config = json.load(f)
    else:
        config = {}
    
    # 更新配置
    config.update({
        "device-mode": "cuda",  # 启用CUDA加速
        "models-dir": "/app/models",  # 模型目录
        "formula-config": {
            "mfd_model": "yolo_v8_ft",
            "mfr_model": "unimernet_small",
            "enable": True
        },
        "layout-config": {
            "model": "doclayout_yolo"
        },
        "weights": {
            "yolo_v8_ft": "MFD/YOLO/yolo_v8_ft.pt",
            "unimernet_small": "MFR/unimernet_small.onnx",
            "doclayout_yolo": "layout/doclayout_yolo.pt"
        },
        "table-config": {
            "model": "rapid_table",
            "sub_model": "slanet_plus",
            "enable": True
        }
    })
    
    # 保存配置
    with open(config_path, "w") as f:
        json.dump(config, f, indent=2)
    
    logger.info(f"CUDA acceleration enabled in config: {config_path}")
    
    # 启动其他任务
    asyncio.create_task(recover_hanging_tasks())
    asyncio.create_task(cleanup_old_tasks())

@app.on_event("shutdown")
async def shutdown_event():
    # 清理资源
    pass

# 单独定义清理任务函数
async def cleanup_old_tasks():
    while True:
        try:
            current_time = datetime.now()
            for task_id in list(task_results.keys()):
                if (current_time - task_results[task_id].created_at) > timedelta(hours=1):
                    del task_results[task_id]
            await asyncio.sleep(3600)  # 每小时清理一次
        except Exception as e:
            logger.error(f"Error in cleanup: {str(e)}")

@app.post("/process_pdf_and_return/")
async def process_pdf_and_return(
    file: UploadFile = File(...),
    ocr: bool = True
):
    task_id = None
    try:
        # 1. 上传文件
        task_id = str(uuid.uuid4())
        task_dir = f"/data/uploads/{task_id}"
        output_dir = f"/data/results/{task_id}"
        os.makedirs(task_dir, exist_ok=True)
        os.makedirs(output_dir, exist_ok=True)
        os.makedirs(f"{output_dir}/images", exist_ok=True)
        
        # 保存文件
        file_path = os.path.join(task_dir, file.filename)
        with open(file_path, "wb") as buffer:
            chunk_size = 4 * 1024 * 1024
            while True:
                chunk = await file.read(chunk_size)
                if not chunk:
                    break
                buffer.write(chunk)
        
        # 2. 创建处理脚本
        base_name = os.path.splitext(file.filename)[0]
        script_path = os.path.join("/data/uploads", f"{task_id}_process.py")
        
        with open(script_path, "w") as f:
            f.write(f"""
import os
import sys
import time
import json
from magic_pdf import Dataset
from magic_pdf.model.doc_analyze_by_custom_model import doc_analyze

# 确保目录存在
os.makedirs("{output_dir}", exist_ok=True)
os.makedirs("{output_dir}/images", exist_ok=True)

# 处理PDF
start_time = time.time()

# 创建数据集
ds = Dataset(
    pdf_path="{file_path}",
    output_dir="{output_dir}",
    config_path="/root/magic-pdf.json"
)

# 应用文档分析
try:
    infer_result = ds.apply(doc_analyze, ocr={str(ocr).lower()})
except KeyError as e:
    # 捕获 KeyError 并尝试修复
    print(f"捕获到 KeyError: {{e}}")
    
    # 修复配置
    import magic_pdf.model.pdf_extract_kit
    if hasattr(magic_pdf.model.pdf_extract_kit.CustomPEKModel, '_original_init'):
        # 已经被修补过
        pass
    else:
        # 保存原始的 __init__ 方法
        magic_pdf.model.pdf_extract_kit.CustomPEKModel._original_init = magic_pdf.model.pdf_extract_kit.CustomPEKModel.__init__
        
        # 定义补丁版本
        def patched_init(self, ocr=False, show_log=False, **kwargs):
            try:
                magic_pdf.model.pdf_extract_kit.CustomPEKModel._original_init(self, ocr, show_log, **kwargs)
            except KeyError as e:
                if str(e).strip("'") in ["yolo_v8_ft", "yolo_v8_mfd"]:
                    # 修改 self.configs 添加缺失的配置
                    if not hasattr(self, 'configs'):
                        self.configs = {{}}
                    
                    if 'weights' not in self.configs:
                        self.configs['weights'] = {{}}
                    
                    self.configs['weights']['yolo_v8_mfd'] = "MFD/YOLO/yolo_v8_mfd.pt"
                    self.configs['weights']['yolo_v8_ft'] = "MFD/YOLO/yolo_v8_ft.pt"
                    self.configs['weights']['unimernet_small'] = "MFR/unimernet_small.onnx"
                    self.configs['weights']['doclayout_yolo'] = "Layout/YOLO/doclayout_yolo.pt"
                    
                    # 重新调用原始方法
                    magic_pdf.model.pdf_extract_kit.CustomPEKModel._original_init(self, ocr, show_log, **kwargs)
                else:
                    raise
        
        # 替换为补丁版本
        magic_pdf.model.pdf_extract_kit.CustomPEKModel.__init__ = patched_init
    
    # 重新尝试
    infer_result = ds.apply(doc_analyze, ocr={str(ocr).lower()})

# 保存处理时间
processing_time = time.time() - start_time
with open("{output_dir}/processing_time.txt", "w") as f:
    f.write(str(processing_time))

# 退出
sys.exit(0)
""")
        
        # 3. 执行处理脚本
        start_time = time.time()
        
        # 设置超时
        process = subprocess.Popen(
            ["python", script_path],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE
        )
        
        try:
            stdout, stderr = process.communicate(timeout=PROCESS_TIMEOUT)
            if process.returncode != 0:
                logger.error(f"PDF处理失败: {stderr.decode('utf-8', errors='ignore')}")
                raise Exception(f"PDF处理失败: {stderr.decode('utf-8', errors='ignore')}")
        except subprocess.TimeoutExpired:
            process.kill()
            raise
        
        processing_time = time.time() - start_time
        
        # 读取处理结果
        all_files = os.listdir(output_dir)
        
        # 读取Markdown
        markdown_path = os.path.join(output_dir, f"{base_name}.md")
        if not os.path.exists(markdown_path):
            # 尝试查找任何.md文件
            md_files = [f for f in all_files if f.endswith('.md') and not f.endswith('_model.md') and not f.endswith('_layout.md') and not f.endswith('_spans.md')]
            if md_files:
                markdown_path = os.path.join(output_dir, md_files[0])
                logger.info(f"Using alternative markdown file: {md_files[0]}")
            else:
                raise HTTPException(
                    status_code=500,
                    detail="Markdown file not generated"
                )
        
        with open(markdown_path, 'r', encoding='utf-8') as f:
            markdown_content = f.read()
        
        # 读取内容列表
        content_list_path = os.path.join(output_dir, f"{base_name}_content_list.json")
        if not os.path.exists(content_list_path):
            # 尝试查找任何_content_list.json文件
            content_list_files = [f for f in all_files if f.endswith('_content_list.json')]
            if content_list_files:
                content_list_path = os.path.join(output_dir, content_list_files[0])
                logger.info(f"Using alternative content list file: {content_list_files[0]}")
        
        if os.path.exists(content_list_path):
            with open(content_list_path, 'r', encoding='utf-8') as f:
                content_list = f.read()
        else:
            content_list = "{}"
            logger.warning(f"Content list file not found: {content_list_path}")
        
        # 读取中间JSON
        middle_json_path = os.path.join(output_dir, f"{base_name}_middle.json")
        if not os.path.exists(middle_json_path):
            # 尝试查找任何_middle.json文件
            middle_json_files = [f for f in all_files if f.endswith('_middle.json')]
            if middle_json_files:
                middle_json_path = os.path.join(output_dir, middle_json_files[0])
                logger.info(f"Using alternative middle json file: {middle_json_files[0]}")
        
        if os.path.exists(middle_json_path):
            with open(middle_json_path, 'r', encoding='utf-8') as f:
                middle_json = f.read()
        else:
            middle_json = "{}"
            logger.warning(f"Middle JSON file not found: {middle_json_path}")
        
        # 4. 返回结果
        response = {
            "status": "completed",
            "processing_time": processing_time,
            "markdown": markdown_content,
            "content_list": content_list,
            "middle_json": middle_json
        }
        
        return JSONResponse(content=response)
        
    except subprocess.TimeoutExpired:
        logger.error(f"PDF processing timeout after {PROCESS_TIMEOUT} seconds")
        raise HTTPException(
            status_code=500,
            detail=f"PDF processing timeout after {PROCESS_TIMEOUT} seconds"
        )
    except Exception as e:
        logger.error(f"Error processing PDF: {str(e)}", exc_info=True)
        raise HTTPException(
            status_code=500,
            detail=f"Error processing PDF: {str(e)}"
        )
    finally:
        # 5. 清理临时文件
        if task_id:
            try:
                # 删除上传目录
                upload_dir = f"/data/uploads/{task_id}"
                if os.path.exists(upload_dir):
                    shutil.rmtree(upload_dir, ignore_errors=True)
                
                # 删除处理脚本
                script_path = os.path.join("/data/uploads", f"{task_id}_process.py")
                if os.path.exists(script_path):
                    os.remove(script_path)
                
                # 删除结果目录
                result_dir = f"/data/results/{task_id}"
                if os.path.exists(result_dir):
                    shutil.rmtree(result_dir, ignore_errors=True)
                
                logger.info(f"Temporary files cleaned up for task {task_id}")
            except Exception as e:
                logger.error(f"Error cleaning up temporary files: {str(e)}")

@app.get("/gpu_status")
async def gpu_status():
    try:
        # 检查NVIDIA驱动是否可用
        result = subprocess.run(
            ["nvidia-smi"], 
            capture_output=True, 
            text=True
        )
        
        if result.returncode == 0:
            # 检查PyTorch是否可以使用CUDA
            import torch
            cuda_available = torch.cuda.is_available()
            device_count = torch.cuda.device_count() if cuda_available else 0
            device_names = [torch.cuda.get_device_name(i) for i in range(device_count)] if cuda_available else []
            
            return {
                "nvidia_smi": result.stdout,
                "cuda_available": cuda_available,
                "device_count": device_count,
                "device_names": device_names,
                "torch_version": torch.__version__
            }
        else:
            return {
                "error": "NVIDIA driver not available",
                "details": result.stderr
            }
    except Exception as e:
        return {
            "error": "Error checking GPU status",
            "details": str(e)
        }
