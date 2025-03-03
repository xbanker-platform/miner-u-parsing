from fastapi import FastAPI, UploadFile, File, Form, HTTPException
from fastapi.responses import JSONResponse
import os
import tempfile
import json
import subprocess
import logging
import shutil
from typing import Optional

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
        # 创建临时文件保存上传的PDF
        with tempfile.NamedTemporaryFile(delete=False, suffix=".pdf") as temp_file:
            temp_file_path = temp_file.name
            shutil.copyfileobj(file.file, temp_file)
        
        logger.info(f"保存PDF到临时文件: {temp_file_path}")
        
        # 准备命令行参数
        cmd = [
            "python3", "-m", "magic_pdf.cli", 
            "--input", temp_file_path,
            "--output", f"{temp_file_path}.json"
        ]
        
        if ocr:
            cmd.append("--ocr")
        
        # 执行命令
        logger.info(f"执行命令: {' '.join(cmd)}")
        process = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            env=dict(os.environ, MINERU_TOOLS_CONFIG_JSON="/app/magic-pdf.json")
        )
        
        if process.returncode != 0:
            logger.error(f"处理失败: {process.stderr}")
            raise HTTPException(status_code=500, detail=f"PDF处理失败: {process.stderr}")
        
        # 读取结果
        try:
            with open(f"{temp_file_path}.json", "r", encoding="utf-8") as f:
                result = json.load(f)
        except Exception as e:
            logger.error(f"读取结果失败: {str(e)}")
            raise HTTPException(status_code=500, detail=f"读取结果失败: {str(e)}")
        
        # 清理临时文件
        try:
            os.unlink(temp_file_path)
            os.unlink(f"{temp_file_path}.json")
        except Exception as e:
            logger.warning(f"清理临时文件失败: {str(e)}")
        
        return JSONResponse(content=result)
    
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