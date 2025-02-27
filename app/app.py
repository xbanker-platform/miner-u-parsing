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
from datetime import datetime

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
    allow_methods=["*"],
    allow_headers=["*"],
)

# 存储任务状态
tasks: Dict[str, Dict] = {}

@app.post("/process_pdf/")
async def process_pdf(
    background_tasks: BackgroundTasks,
    file: UploadFile = File(...),
    ocr: bool = True
):
    try:
        # 生成唯一任务ID
        task_id = str(uuid.uuid4())
        
        # 创建任务目录
        task_dir = f"/data/uploads/{task_id}"
        output_dir = f"/data/results/{task_id}"
        os.makedirs(task_dir, exist_ok=True)
        os.makedirs(f"{output_dir}/images", exist_ok=True)
        
        # 保存上传的文件
        file_path = os.path.join(task_dir, file.filename)
        with open(file_path, "wb") as buffer:
            shutil.copyfileobj(file.file, buffer)
        
        # 更新任务状态
        tasks[task_id] = {
            "id": task_id,
            "filename": file.filename,
            "status": "processing",
            "created_at": datetime.now().isoformat(),
            "output_dir": output_dir,
            "ocr": ocr
        }
        
        # 在后台处理PDF
        background_tasks.add_task(process_pdf_task, task_id, file_path, output_dir, ocr)
        
        return {
            "task_id": task_id,
            "status": "processing",
            "message": "PDF processing started"
        }
            
    except Exception as e:
        logger.error(f"Error processing PDF: {str(e)}", exc_info=True)
        raise HTTPException(
            status_code=500,
            detail=f"Error processing PDF: {str(e)}"
        )

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
            tasks[task_id]["status"] = "failed"
            tasks[task_id]["error"] = result.stderr
            return
        
        # 更新任务状态
        tasks[task_id]["status"] = "completed"
        tasks[task_id]["completed_at"] = datetime.now().isoformat()
        
        # 记录输出文件
        output_files = []
        for root, _, files in os.walk(output_dir):
            for file in files:
                rel_path = os.path.relpath(os.path.join(root, file), output_dir)
                output_files.append(rel_path)
        
        tasks[task_id]["output_files"] = output_files
        
    except Exception as e:
        logger.error(f"Error in background task: {str(e)}", exc_info=True)
        tasks[task_id]["status"] = "failed"
        tasks[task_id]["error"] = str(e)

@app.get("/tasks/{task_id}")
async def get_task_status(task_id: str):
    if task_id not in tasks:
        raise HTTPException(status_code=404, detail="Task not found")
    
    return tasks[task_id]

@app.get("/tasks")
async def list_tasks():
    return list(tasks.values())

@app.get("/download/{task_id}/{file_path:path}")
async def download_file(task_id: str, file_path: str):
    if task_id not in tasks:
        raise HTTPException(status_code=404, detail="Task not found")
    
    task = tasks[task_id]
    file_full_path = os.path.join(task["output_dir"], file_path)
    
    if not os.path.exists(file_full_path):
        raise HTTPException(status_code=404, detail="File not found")
    
    return FileResponse(file_full_path)

@app.delete("/tasks/{task_id}")
async def delete_task(task_id: str):
    if task_id not in tasks:
        raise HTTPException(status_code=404, detail="Task not found")
    
    # 删除任务文件
    task = tasks[task_id]
    shutil.rmtree(f"/data/uploads/{task_id}", ignore_errors=True)
    shutil.rmtree(task["output_dir"], ignore_errors=True)
    
    # 删除任务记录
    del tasks[task_id]
    
    return {"message": "Task deleted successfully"}

@app.get("/health")
async def health_check():
    # 检查GPU状态
    try:
        result = subprocess.run(
            ["nvidia-smi"], 
            capture_output=True, 
            text=True
        )
        gpu_available = result.returncode == 0
    except:
        gpu_available = False
    
    return {
        "status": "healthy",
        "gpu_available": gpu_available,
        "timestamp": datetime.now().isoformat()
    }

@app.get("/")
async def root():
    return {"message": "MinerU API is running. Visit /docs for API documentation."}
