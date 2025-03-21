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
    def __init__(self, max_concurrent=6):
        self.max_concurrent = max_concurrent
        self.processing = {}  # 正在处理的任务，格式：{task_id: task_func}
        self.resource_monitor = ResourceMonitor()
    
    async def estimate_task_memory(self, pdf_bytes: bytes) -> int:
        """
        预估任务所需的显存大小
        可以根据PDF页数、大小等进行估算
        """
        # 这里需要根据实际情况实现预估逻辑
        pdf_size = len(pdf_bytes)
        estimated_memory = pdf_size * 0.1  # 示例：每字节预估0.1MB显存
        return int(estimated_memory)
    
    async def add_task(self, task_id, task_func, pdf_bytes: bytes = None):
        """
        添加任务到GPU队列
        
        Args:
            task_id: 任务ID
            task_func: 任务函数
            pdf_bytes: PDF文件内容，用于预估显存
        """
        if len(self.processing) >= self.max_concurrent:
            logger.warning(f"GPU队列已满，无法添加任务，任务ID: {task_id}")
            return False
            
        # 如果提供了PDF内容，预估显存需求
        if pdf_bytes:
            estimated_memory = await self.estimate_task_memory(pdf_bytes)
            
            # 检查当前显存是否足够
            gpu_info = get_gpu_info()
            if not gpu_info:
                logger.error("无法获取GPU信息，拒绝任务")
                return False
                
            available_memory = gpu_info['total'] - gpu_info['used']
            if available_memory < estimated_memory:
                logger.warning(f"显存不足，拒绝任务 {task_id}，需要 {estimated_memory}MB，可用 {available_memory}MB")
                return False
                
            # 记录任务显存使用情况
            self.resource_monitor.task_memory_usage[task_id] = estimated_memory
        
        # 添加任务到处理队列
        self.processing[task_id] = task_func
        
        # 创建任务处理协程
        asyncio.create_task(self._process_task(task_id, task_func))
        
        return True
    
    async def _process_task(self, task_id, task_func):
        """
        处理任务
        
        Args:
            task_id: 任务ID
            task_func: 任务函数
        """
        try:
            # 执行任务
            await task_func()
        except Exception as e:
            logger.error(f"处理任务时出错，任务ID: {task_id}, 错误: {str(e)}")
        finally:
            # 从处理队列中移除任务
            if task_id in self.processing:
                del self.processing[task_id]
            # 清理任务显存记录
            if task_id in self.resource_monitor.task_memory_usage:
                del self.resource_monitor.task_memory_usage[task_id]

def get_gpu_info():
    try:
        # 获取总显存
        total_memory = subprocess.run(
            ['nvidia-smi', '--query-gpu=memory.total', '--format=csv,nounits,noheader'],
            capture_output=True, text=True
        ).stdout.strip()
        
        # 获取已使用显存
        used_memory = subprocess.run(
            ['nvidia-smi', '--query-gpu=memory.used', '--format=csv,nounits,noheader'],
            capture_output=True, text=True
        ).stdout.strip()
        
        # 获取显存使用率
        utilization = subprocess.run(
            ['nvidia-smi', '--query-gpu=utilization.gpu', '--format=csv,nounits,noheader'],
            capture_output=True, text=True
        ).stdout.strip()
        
        return {
            'total': int(total_memory),
            'used': int(used_memory),
            'utilization': int(utilization),
            'usage_percentage': (int(used_memory) / int(total_memory)) * 100
        }
    except Exception as e:
        logger.error(f"获取GPU信息失败: {str(e)}")
        return None

class ResourceMonitor:
    def __init__(self):
        self.warning_threshold = 0.8  # 80%警告阈值
        self.critical_threshold = 0.9  # 90%临界阈值
        self.min_concurrent = 1  # 最小并发数
        self.max_concurrent = 6  # 最大并发数
        self.current_concurrent = 4  # 当前并发数
        self.task_memory_usage = {}  # 记录每个任务的显存使用情况
        
    async def monitor(self):
        while True:
            gpu_info = get_gpu_info()
            if not gpu_info:
                await asyncio.sleep(5)
                continue
                
            usage_percentage = gpu_info['usage_percentage'] / 100
            
            # 根据使用率动态调整并发数
            if usage_percentage > self.critical_threshold:
                # 显存使用率过高，减少并发数
                self.current_concurrent = max(self.min_concurrent, self.current_concurrent - 1)
                logger.warning(f"GPU使用率过高 ({usage_percentage:.2%})，减少并发数至 {self.current_concurrent}")
            elif usage_percentage < self.warning_threshold:
                # 显存使用率较低，可以增加并发数
                self.current_concurrent = min(self.max_concurrent, self.current_concurrent + 1)
                logger.info(f"GPU使用率较低 ({usage_percentage:.2%})，增加并发数至 {self.current_concurrent}")
            
            # 更新GPU队列的最大并发数
            gpu_task_queue.max_concurrent = self.current_concurrent
            
            await asyncio.sleep(5)

class PriorityTaskQueue:
    def __init__(self):
        self.high_priority = Queue()
        self.normal_priority = Queue()
        
    async def add_task(self, task_id, task_func, priority='normal'):
        queue = self.high_priority if priority == 'high' else self.normal_priority
        await queue.put((task_id, task_func))
    
    def get_queue_length(self, priority='normal'):
        queue = self.high_priority if priority == 'high' else self.normal_priority
        return queue.qsize()

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
    file: UploadFile = File(...),
    ocr: Optional[bool] = Form(False),
    priority: Optional[str] = Form("normal"),
    callback_url: Optional[str] = Form(None)
):
    """
    接收PDF处理请求，立即返回任务ID，然后将任务放入队列中等待处理
    处理完成后，将结果上传到S3，并调用API Gateway通知处理结果
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
        "callback_url": callback_url,
        "queue_position": priority_queue.get_queue_length(priority),
        "pdf_bytes": pdf_bytes  # 保存PDF内容用于显存预估
    }
    
    # 创建处理任务函数
    async def process_task():
        await process_pdf_in_background(task_id, pdf_bytes, file_name, ocr, priority)
    
    # 将任务添加到优先级队列
    await priority_queue.add_task(task_id, process_task, priority)
    
    # 获取队列中的任务数量
    queue_info = {
        "high_priority": priority_queue.high_priority.qsize(),
        "normal_priority": priority_queue.normal_priority.qsize(),
        "processing": len(gpu_task_queue.processing),
        "max_concurrent": gpu_task_queue.max_concurrent
    }
    
    logger.info(f"任务已添加到队列，任务ID: {task_id}, 队列信息: {queue_info}")
    
    return {
        "task_id": task_id,
        "status": "queued",
        "message": "PDF处理请求已接收，正在排队处理",
        "queue_info": queue_info
    }

@app.post("/order/")
async def order_pdf_processing_with_slash(
    file: UploadFile = File(...),
    ocr: Optional[bool] = Form(False),
    priority: Optional[str] = Form("normal"),
    callback_url: Optional[str] = Form(None)
):
    """
    与/order端点功能相同，但支持带斜杠的URL
    """
    return await order_pdf_processing(file, ocr, priority, callback_url)

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
        
        # 测试S3连接
        logger.info(f"测试S3连接，桶名: {Config.s3_bucket_name}, 区域: {Config.s3_region}")
        test_key = f"{task_id}/test_connection.txt"
        test_content = "测试S3连接"
        upload_success = s3_client.upload_object(test_content, Config.s3_bucket_name, test_key)
        if not upload_success:
            raise Exception(f"无法连接到S3桶 {Config.s3_bucket_name}，请检查AWS凭证和S3桶配置")
        s3_files.append(test_key)
        
        # 上传Markdown文件
        s3_md_key = f"{s3_file_prefix}.md"
        logger.info(f"上传Markdown文件: {md_file_path} -> {s3_md_key}")
        if not s3_client.upload_file(md_file_path, Config.s3_bucket_name, s3_md_key):
            raise Exception(f"上传Markdown文件失败: {md_file_path} -> {Config.s3_bucket_name}/{s3_md_key}")
        s3_files.append(s3_md_key)
        
        # 上传内容列表文件
        s3_content_list_key = f"{s3_file_prefix}_content_list.json"
        logger.info(f"上传内容列表文件: {content_list_file_path} -> {s3_content_list_key}")
        if not s3_client.upload_file(content_list_file_path, Config.s3_bucket_name, s3_content_list_key):
            raise Exception(f"上传内容列表文件失败: {content_list_file_path} -> {Config.s3_bucket_name}/{s3_content_list_key}")
        s3_files.append(s3_content_list_key)
        
        # 上传中间JSON文件
        s3_middle_json_key = f"{s3_file_prefix}_middle.json"
        logger.info(f"上传中间JSON文件: {middle_json_file_path} -> {s3_middle_json_key}")
        if not s3_client.upload_file(middle_json_file_path, Config.s3_bucket_name, s3_middle_json_key):
            raise Exception(f"上传中间JSON文件失败: {middle_json_file_path} -> {Config.s3_bucket_name}/{s3_middle_json_key}")
        s3_files.append(s3_middle_json_key)
        
        # 上传图片文件
        for img_file in os.listdir(images_dir):
            img_path = os.path.join(images_dir, img_file)
            s3_img_key = f"{s3_file_prefix}/images/{img_file}"
            logger.info(f"上传图片文件: {img_path} -> {s3_img_key}")
            if not s3_client.upload_file(img_path, Config.s3_bucket_name, s3_img_key):
                raise Exception(f"上传图片文件失败: {img_path} -> {Config.s3_bucket_name}/{s3_img_key}")
            s3_files.append(s3_img_key)
        
        # 更新任务状态
        task_status[task_id]["status"] = "completed"
        task_status[task_id]["completed_at"] = time.time()
        task_status[task_id]["s3_files"] = s3_files
        task_status[task_id]["s3_bucket"] = Config.s3_bucket_name
        
        # 调用API Gateway通知处理结果
        logger.info(f"调用API Gateway通知处理结果: {Config.api_gateway_url}")
        api_result = api_client.notify_processing_result(
            task_id=task_id,
            success=True,
            bucket_name=Config.s3_bucket_name,
            file_keys=s3_files
        )
        
        if not api_result:
            logger.warning(f"调用API Gateway失败，但PDF处理已完成，任务ID: {task_id}")
            task_status[task_id]["api_gateway_notification"] = "failed"
        else:
            task_status[task_id]["api_gateway_notification"] = "success"
        
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
        try:
            api_client.notify_processing_result(
                task_id=task_id,
                success=False,
                bucket_name=Config.s3_bucket_name,
                file_keys=[],
                error_message=error_message
            )
        except Exception as api_error:
            logger.error(f"调用API Gateway通知失败时出错，任务ID: {task_id}, 错误: {str(api_error)}")
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

@app.get("/tasks")
async def get_all_tasks():
    """
    获取所有任务的状态
    
    Returns:
        所有任务的状态
    """
    # 获取队列信息
    queue_info = {
        "high_priority": priority_queue.high_priority.qsize(),
        "normal_priority": priority_queue.normal_priority.qsize(),
        "processing": len(gpu_task_queue.processing),
        "max_concurrent": gpu_task_queue.max_concurrent
    }
    
    # 获取任务状态
    tasks_info = {}
    for task_id, status in task_status.items():
        # 复制状态信息，避免修改原始数据
        task_info = status.copy()
        
        # 添加任务运行时间
        if "started_at" in task_info and task_info["status"] == "processing":
            task_info["running_time"] = time.time() - task_info["started_at"]
        
        # 添加任务等待时间
        if "created_at" in task_info and task_info["status"] == "queued":
            task_info["waiting_time"] = time.time() - task_info["created_at"]
        
        # 添加任务完成时间
        if "completed_at" in task_info and "started_at" in task_info:
            task_info["processing_time"] = task_info["completed_at"] - task_info["started_at"]
        
        tasks_info[task_id] = task_info
    
    return {
        "queue_info": queue_info,
        "tasks": tasks_info
    }

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

gpu_task_queue = GPUTaskQueue(max_concurrent=5)

resource_monitor = ResourceMonitor()

@app.on_event("startup")
async def startup_event():
    # 启动优先级队列处理器
    asyncio.create_task(process_priority_queue())
    logger.info("优先级队列处理器已启动")
    
    # 初始化任务状态字典
    global task_status
    task_status = {}
    
    logger.info("应用已启动")

async def process_priority_queue():
    """
    处理优先级队列中的任务
    先处理高优先级队列，再处理普通优先级队列
    限制最大并发任务数
    """
    while True:
        # 检查是否有空闲的GPU资源
        if len(gpu_task_queue.processing) < gpu_task_queue.max_concurrent:
            # 先处理高优先级队列
            if not priority_queue.high_priority.empty():
                task_id, task_func = await priority_queue.high_priority.get()
                logger.info(f"从高优先级队列获取任务，任务ID: {task_id}")
                # 更新任务状态
                if task_id in task_status:
                    task_status[task_id]["status"] = "processing"
                    task_status[task_id]["started_at"] = time.time()
                    # 获取PDF内容用于显存预估
                    pdf_bytes = task_status[task_id].get("pdf_bytes")
                    # 将任务添加到GPU队列
                    if await gpu_task_queue.add_task(task_id, task_func, pdf_bytes):
                        logger.info(f"任务 {task_id} 已添加到GPU队列")
                    else:
                        # 如果显存不足，将任务重新放回队列
                        await priority_queue.high_priority.put((task_id, task_func))
                        logger.warning(f"任务 {task_id} 显存不足，重新放回队列")
                        task_status[task_id]["status"] = "queued"
                        task_status[task_id]["error"] = "显存不足，等待资源释放"
            # 再处理普通优先级队列
            elif not priority_queue.normal_priority.empty():
                task_id, task_func = await priority_queue.normal_priority.get()
                logger.info(f"从普通优先级队列获取任务，任务ID: {task_id}")
                # 更新任务状态
                if task_id in task_status:
                    task_status[task_id]["status"] = "processing"
                    task_status[task_id]["started_at"] = time.time()
                    # 获取PDF内容用于显存预估
                    pdf_bytes = task_status[task_id].get("pdf_bytes")
                    # 将任务添加到GPU队列
                    if await gpu_task_queue.add_task(task_id, task_func, pdf_bytes):
                        logger.info(f"任务 {task_id} 已添加到GPU队列")
                    else:
                        # 如果显存不足，将任务重新放回队列
                        await priority_queue.normal_priority.put((task_id, task_func))
                        logger.warning(f"任务 {task_id} 显存不足，重新放回队列")
                        task_status[task_id]["status"] = "queued"
                        task_status[task_id]["error"] = "显存不足，等待资源释放"
        
        # 记录队列状态
        queue_info = {
            "high_priority": priority_queue.high_priority.qsize(),
            "normal_priority": priority_queue.normal_priority.qsize(),
            "processing": len(gpu_task_queue.processing),
            "max_concurrent": gpu_task_queue.max_concurrent
        }
        logger.debug(f"队列状态: {queue_info}")
        
        # 等待一段时间再检查
        await asyncio.sleep(0.1) 

@app.get("/gpu_status")
async def get_gpu_status():
    """获取GPU状态信息"""
    gpu_info = get_gpu_info()
    if not gpu_info:
        raise HTTPException(status_code=500, detail="无法获取GPU信息")
        
    return {
        "gpu_info": gpu_info,
        "task_queue": {
            "current_concurrent": gpu_task_queue.resource_monitor.current_concurrent,
            "max_concurrent": gpu_task_queue.max_concurrent,
            "processing_tasks": len(gpu_task_queue.processing),
            "task_memory_usage": gpu_task_queue.resource_monitor.task_memory_usage
        }
    } 