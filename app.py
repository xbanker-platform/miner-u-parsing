from fastapi import FastAPI, UploadFile, File, Form, HTTPException, BackgroundTasks
from fastapi.responses import JSONResponse
import os
import tempfile
import json
import logging
import shutil
from typing import Optional, Dict, List
import io
import subprocess
import asyncio
from asyncio import Queue
import uuid
import time

# 导入magic-pdf相关模块
from magic_pdf.data.data_reader_writer import FileBasedDataWriter
from magic_pdf.data.dataset import PymuDocDataset
from magic_pdf.model.doc_analyze_by_custom_model import doc_analyze
from magic_pdf.config.enums import SupportedPdfParseMethod

# 导入自定义模块
from s3_proxy import get_oss_instance
from api_gateway_client import get_api_gateway_client
from config import Config

app = FastAPI(title="MinerU API", description="PDF解析服务API")

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# 任务状态存储
task_status: Dict[str, Dict] = {}

class GPUTaskQueue:
    def __init__(self, max_concurrent=4):
        self.queue = Queue()
        self.processing = set()
        self.max_concurrent = max_concurrent
        
    async def add_task(self, task_id, task_func):
        await self.queue.put((task_id, task_func))
        
    async def process_queue(self):
        while True:
            if len(self.processing) < self.max_concurrent:
                if not self.queue.empty():
                    task_id, task_func = await self.queue.get()
                    self.processing.add(task_id)
                    try:
                        await task_func()
                    finally:
                        self.processing.remove(task_id)
            await asyncio.sleep(1)

class ResourceMonitor:
    def __init__(self):
        self.gpu_threshold = 0.9  # 90% GPU使用率阈值
        
    async def monitor(self):
        while True:
            gpu_usage = get_gpu_memory_usage()
            if gpu_usage > self.gpu_threshold:
                # 减少并发任务数
                gpu_task_queue.max_concurrent = max(1, gpu_task_queue.max_concurrent - 1)
            else:
                # 增加并发任务数
                gpu_task_queue.max_concurrent = min(4, gpu_task_queue.max_concurrent + 1)
            await asyncio.sleep(5)

class PriorityTaskQueue:
    def __init__(self):
        self.high_priority = Queue()
        self.normal_priority = Queue()
        
    async def add_task(self, task_id, task_func, priority='normal'):
        queue = self.high_priority if priority == 'high' else self.normal_priority
        await queue.put((task_id, task_func))

@app.get("/")
async def root():
    return {"message": "欢迎使用MinerU PDF解析服务"}

@app.post("/process")
async def process_pdf(
    file: UploadFile = File(...),
    ocr: Optional[bool] = Form(False),
    priority: Optional[str] = Form("normal")
):
    task_id = str(uuid.uuid4())
    pdf_bytes = await file.read()
    
    async def process_task():
        try:
            # 创建临时目录
            temp_dir = tempfile.mkdtemp()
            output_dir = os.path.join(temp_dir, "output")
            images_dir = os.path.join(output_dir, "images")
            os.makedirs(images_dir, exist_ok=True)
            
            # 准备文件名
            file_name = file.filename or "uploaded.pdf"
            name_without_suffix = os.path.splitext(file_name)[0]
            
            logger.info(f"处理PDF文件: {file_name}")
            
            # 准备数据写入器
            image_writer = FileBasedDataWriter(images_dir)
            md_writer = FileBasedDataWriter(output_dir)
            
            # 创建数据集实例
            ds = PymuDocDataset(pdf_bytes)
            
            # 推理
            try:
                if ocr or ds.classify() == SupportedPdfParseMethod.OCR:
                    logger.info("使用OCR模式处理PDF")
                    infer_result = ds.apply(doc_analyze, ocr=True)
                    pipe_result = infer_result.pipe_ocr_mode(image_writer)
                else:
                    logger.info("使用文本模式处理PDF")
                    infer_result = ds.apply(doc_analyze, ocr=False)
                    pipe_result = infer_result.pipe_txt_mode(image_writer)
                
                 # 获取markdown内容
                markdown_content = pipe_result.get_markdown("images")
                
                # 保存Markdown
                pipe_result.dump_md(md_writer, f"{name_without_suffix}.md", "images")
                
                # 获取内容列表
                content_list_content = pipe_result.get_content_list("images")
                
                # 保存内容列表
                pipe_result.dump_content_list(md_writer, f"{name_without_suffix}_content_list.json", "images")
                
                # 获取中间JSON
                middle_json_content = pipe_result.get_middle_json()
                
                # 保存中间JSON
                pipe_result.dump_middle_json(md_writer, f"{name_without_suffix}_middle.json")
                
                
                # 构建响应
                response = {
                    "status": "completed",
                    "markdown": markdown_content,
                    "content_list": content_list_content,
                    "middle_json": middle_json_content
                }
                
                return JSONResponse(content=response)
                
            except Exception as e:
                logger.error(f"处理PDF时出错: {str(e)}")
                raise HTTPException(status_code=500, detail=f"PDF处理失败: {str(e)}")
            finally:
                # 清理临时文件
                try:
                    shutil.rmtree(temp_dir, ignore_errors=True)
                except Exception as e:
                    logger.warning(f"清理临时文件失败: {str(e)}")
        
        except Exception as e:
            logger.exception("处理PDF时发生错误")
            raise HTTPException(status_code=500, detail=str(e))
    
    await priority_queue.add_task(task_id, process_task, priority)
    return {"task_id": task_id, "status": "queued", "priority": priority}

@app.post("/process_pdf_and_return/")
async def process_pdf_and_return(
    file: UploadFile = File(...),
    ocr: Optional[bool] = Form(False)
):
    """兼容旧API的端点，直接处理PDF并返回结果"""
    try:
        # 读取上传的PDF文件内容
        pdf_bytes = await file.read()
        
        # 创建临时目录
        temp_dir = tempfile.mkdtemp()
        output_dir = os.path.join(temp_dir, "output")
        images_dir = os.path.join(output_dir, "images")
        os.makedirs(images_dir, exist_ok=True)
        
        # 准备文件名
        file_name = file.filename or "uploaded.pdf"
        name_without_suffix = os.path.splitext(file_name)[0]
        
        logger.info(f"处理PDF文件: {file_name}")
        
        # 准备数据写入器
        image_writer = FileBasedDataWriter(images_dir)
        md_writer = FileBasedDataWriter(output_dir)
        
        # 创建数据集实例
        ds = PymuDocDataset(pdf_bytes)
        
        # 推理
        try:
            if ocr or ds.classify() == SupportedPdfParseMethod.OCR:
                logger.info("使用OCR模式处理PDF")
                infer_result = ds.apply(doc_analyze, ocr=True)
                pipe_result = infer_result.pipe_ocr_mode(image_writer)
            else:
                logger.info("使用文本模式处理PDF")
                infer_result = ds.apply(doc_analyze, ocr=False)
                pipe_result = infer_result.pipe_txt_mode(image_writer)
            
             # 获取markdown内容
            markdown_content = pipe_result.get_markdown("images")
            
            # 保存Markdown
            pipe_result.dump_md(md_writer, f"{name_without_suffix}.md", "images")
            
            # 获取内容列表
            content_list_content = pipe_result.get_content_list("images")
            
            # 保存内容列表
            pipe_result.dump_content_list(md_writer, f"{name_without_suffix}_content_list.json", "images")
            
            # 获取中间JSON
            middle_json_content = pipe_result.get_middle_json()
            
            # 保存中间JSON
            pipe_result.dump_middle_json(md_writer, f"{name_without_suffix}_middle.json")
            
            
            # 构建响应
            response = {
                "status": "completed",
                "markdown": markdown_content,
                "content_list": content_list_content,
                "middle_json": middle_json_content
            }
            
            return JSONResponse(content=response)
            
        except Exception as e:
            logger.error(f"处理PDF时出错: {str(e)}")
            raise HTTPException(status_code=500, detail=f"PDF处理失败: {str(e)}")
        finally:
            # 清理临时文件
            try:
                shutil.rmtree(temp_dir, ignore_errors=True)
            except Exception as e:
                logger.warning(f"清理临时文件失败: {str(e)}")
    
    except Exception as e:
        logger.exception("处理PDF时发生错误")
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/order")
async def order_pdf_processing(
    background_tasks: BackgroundTasks,
    file: UploadFile = File(...),
    ocr: Optional[bool] = Form(False),
    priority: Optional[str] = Form("normal"),
    callback_url: Optional[str] = Form(None)
):
    """
    接收PDF处理请求，立即返回任务ID，然后在后台处理PDF
    处理完成后，将结果上传到S3，并调用API Gateway通知处理结果
    
    Args:
        background_tasks: FastAPI后台任务
        file: 上传的PDF文件
        ocr: 是否使用OCR
        priority: 任务优先级
        callback_url: 可选的回调URL
        
    Returns:
        任务ID和状态
    """
    task_id = str(uuid.uuid4())
    pdf_bytes = await file.read()
    file_name = file.filename or f"uploaded_{task_id}.pdf"
    name_without_suffix = os.path.splitext(file_name)[0]
    
    # 更新任务状态
    task_status[task_id] = {
        "status": "queued",
        "priority": priority,
        "file_name": file_name,
        "created_at": time.time(),
        "callback_url": callback_url
    }
    
    # 添加后台任务
    background_tasks.add_task(
        process_pdf_in_background,
        task_id,
        pdf_bytes,
        file_name,
        ocr,
        priority
    )
    
    return {
        "task_id": task_id,
        "status": "queued",
        "message": "PDF处理请求已接收，正在后台处理"
    }

async def process_pdf_in_background(task_id: str, pdf_bytes: bytes, file_name: str, ocr: bool, priority: str):
    """
    在后台处理PDF文件
    
    Args:
        task_id: 任务ID
        pdf_bytes: PDF文件内容
        file_name: 文件名
        ocr: 是否使用OCR
        priority: 任务优先级
    """
    # 更新任务状态
    task_status[task_id]["status"] = "processing"
    task_status[task_id]["started_at"] = time.time()
    
    # 获取S3客户端
    s3_client = get_oss_instance()
    
    # 获取API Gateway客户端
    api_client = get_api_gateway_client()
    
    # 创建临时目录
    temp_dir = tempfile.mkdtemp()
    output_dir = os.path.join(temp_dir, "output")
    images_dir = os.path.join(output_dir, "images")
    os.makedirs(images_dir, exist_ok=True)
    
    try:
        # 准备文件名
        name_without_suffix = os.path.splitext(file_name)[0]
        
        logger.info(f"后台处理PDF文件: {file_name}, 任务ID: {task_id}")
        
        # 准备数据写入器
        image_writer = FileBasedDataWriter(images_dir)
        md_writer = FileBasedDataWriter(output_dir)
        
        # 创建数据集实例
        ds = PymuDocDataset(pdf_bytes)
        
        # 推理
        if ocr or ds.classify() == SupportedPdfParseMethod.OCR:
            logger.info(f"使用OCR模式处理PDF, 任务ID: {task_id}")
            infer_result = ds.apply(doc_analyze, ocr=True)
            pipe_result = infer_result.pipe_ocr_mode(image_writer)
        else:
            logger.info(f"使用文本模式处理PDF, 任务ID: {task_id}")
            infer_result = ds.apply(doc_analyze, ocr=False)
            pipe_result = infer_result.pipe_txt_mode(image_writer)
        
        # 获取markdown内容
        markdown_content = pipe_result.get_markdown("images")
        
        # 保存Markdown
        md_file_path = os.path.join(output_dir, f"{name_without_suffix}.md")
        pipe_result.dump_md(md_writer, f"{name_without_suffix}.md", "images")
        
        # 获取内容列表
        content_list_content = pipe_result.get_content_list("images")
        
        # 保存内容列表
        content_list_file_path = os.path.join(output_dir, f"{name_without_suffix}_content_list.json")
        pipe_result.dump_content_list(md_writer, f"{name_without_suffix}_content_list.json", "images")
        
        # 获取中间JSON
        middle_json_content = pipe_result.get_middle_json()
        
        # 保存中间JSON
        middle_json_file_path = os.path.join(output_dir, f"{name_without_suffix}_middle.json")
        pipe_result.dump_middle_json(md_writer, f"{name_without_suffix}_middle.json")
        
        # 上传结果到S3
        s3_file_prefix = f"{task_id}/{name_without_suffix}"
        s3_files = []
        
        # 上传Markdown文件
        s3_md_key = f"{s3_file_prefix}.md"
        s3_client.upload_file(md_file_path, Config.s3_bucket_name, s3_md_key)
        s3_files.append(s3_md_key)
        
        # 上传内容列表文件
        s3_content_list_key = f"{s3_file_prefix}_content_list.json"
        s3_client.upload_file(content_list_file_path, Config.s3_bucket_name, s3_content_list_key)
        s3_files.append(s3_content_list_key)
        
        # 上传中间JSON文件
        s3_middle_json_key = f"{s3_file_prefix}_middle.json"
        s3_client.upload_file(middle_json_file_path, Config.s3_bucket_name, s3_middle_json_key)
        s3_files.append(s3_middle_json_key)
        
        # 上传图片文件
        for img_file in os.listdir(images_dir):
            img_path = os.path.join(images_dir, img_file)
            s3_img_key = f"{s3_file_prefix}/images/{img_file}"
            s3_client.upload_file(img_path, Config.s3_bucket_name, s3_img_key)
            s3_files.append(s3_img_key)
        
        # 更新任务状态
        task_status[task_id]["status"] = "completed"
        task_status[task_id]["completed_at"] = time.time()
        task_status[task_id]["s3_files"] = s3_files
        task_status[task_id]["s3_bucket"] = Config.s3_bucket_name
        
        # 调用API Gateway通知处理结果
        api_client.notify_processing_result(
            task_id=task_id,
            success=True,
            bucket_name=Config.s3_bucket_name,
            file_keys=s3_files
        )
        
        logger.info(f"PDF处理完成，任务ID: {task_id}, 文件已上传到S3")
        
    except Exception as e:
        # 处理失败
        error_message = str(e)
        logger.error(f"处理PDF时出错，任务ID: {task_id}, 错误: {error_message}")
        
        # 更新任务状态
        task_status[task_id]["status"] = "failed"
        task_status[task_id]["error"] = error_message
        task_status[task_id]["completed_at"] = time.time()
        
        # 调用API Gateway通知处理失败
        api_client.notify_processing_result(
            task_id=task_id,
            success=False,
            bucket_name=Config.s3_bucket_name,
            file_keys=[],
            error_message=error_message
        )
    finally:
        # 清理临时文件
        try:
            shutil.rmtree(temp_dir, ignore_errors=True)
        except Exception as e:
            logger.warning(f"清理临时文件失败，任务ID: {task_id}, 错误: {str(e)}")

@app.get("/health")
async def health_check():
    return {"status": "healthy"}

@app.get("/task/{task_id}")
async def get_task_status(task_id: str):
    """获取任务状态"""
    if task_id in task_status:
        return task_status[task_id]
    else:
        raise HTTPException(status_code=404, detail="任务不存在")

def get_gpu_memory_usage():
    try:
        result = subprocess.run(['nvidia-smi', '--query-gpu=memory.used', '--format=csv,nounits,noheader'], 
                              capture_output=True, text=True)
        return int(result.stdout.strip())
    except:
        return 0 

async def process_with_retry(task_id, max_retries=3):
    retries = 0
    while retries < max_retries:
        try:
            return await process_pdf_task(task_id)
        except Exception as e:
            retries += 1
            if retries == max_retries:
                raise
            await asyncio.sleep(1) 

priority_queue = PriorityTaskQueue()

gpu_task_queue = GPUTaskQueue()

resource_monitor = ResourceMonitor()

@app.on_event("startup")
async def startup_event():
    asyncio.create_task(process_priority_queue())
    asyncio.create_task(gpu_task_queue.process_queue())
    asyncio.create_task(resource_monitor.monitor())

async def process_priority_queue():
    while True:
        # 先处理高优先级队列
        if not priority_queue.high_priority.empty():
            task_id, task_func = await priority_queue.high_priority.get()
            await task_func()
        # 再处理普通优先级队列
        elif not priority_queue.normal_priority.empty():
            task_id, task_func = await priority_queue.normal_priority.get()
            await task_func()
        await asyncio.sleep(0.1) 