from fastapi import FastAPI, UploadFile, File, Form, HTTPException
from fastapi.responses import JSONResponse
import os
import tempfile
import json
import logging
import shutil
from typing import Optional
import io

# 导入magic-pdf相关模块
from magic_pdf.data.data_reader_writer import FileBasedDataWriter
from magic_pdf.data.dataset import PymuDocDataset
from magic_pdf.model.doc_analyze_by_custom_model import doc_analyze
from magic_pdf.config.enums import SupportedPdfParseMethod

app = FastAPI(title="MinerU API", description="PDF解析服务API")

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

@app.get("/")
async def root():
    return {"message": "欢迎使用MinerU PDF解析服务"}

@app.post("/process")
async def process_pdf(
    file: UploadFile = File(...),
    ocr: Optional[bool] = Form(False)
):
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

@app.post("/process_pdf_and_return/")
async def process_pdf_and_return(
    file: UploadFile = File(...),
    ocr: Optional[bool] = Form(False)
):
    """兼容旧API的端点"""
    return await process_pdf(file, ocr)

@app.get("/health")
async def health_check():
    return {"status": "healthy"} 