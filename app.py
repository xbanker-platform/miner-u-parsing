from fastapi import FastAPI, UploadFile, File
from fastapi.responses import JSONResponse
import tempfile
import os
import subprocess
import shutil

app = FastAPI(title="MinerU API")

@app.post("/process_pdf/")
async def process_pdf(file: UploadFile = File(...)):
    try:
        # 创建临时目录
        with tempfile.TemporaryDirectory() as temp_dir:
            # 保存上传的文件
            temp_pdf = os.path.join(temp_dir, "input.pdf")
            with open(temp_pdf, "wb") as buffer:
                shutil.copyfileobj(file.file, buffer)
            
            # 创建输出目录
            output_dir = os.path.join(temp_dir, "output")
            os.makedirs(output_dir, exist_ok=True)
            
            # 处理 PDF
            result = subprocess.run(
                ["magic-pdf", "-p", temp_pdf, "-o", output_dir],
                capture_output=True,
                text=True
            )
            
            # 读取结果
            result_file = os.path.join(output_dir, "result.json")
            if os.path.exists(result_file):
                with open(result_file, "r") as f:
                    return JSONResponse(content=f.read())
            
            return {"status": "success", "message": "PDF processed", "output": result.stdout}
            
    except Exception as e:
        return JSONResponse(
            status_code=500,
            content={"status": "error", "message": str(e)}
        )

@app.get("/health")
async def health_check():
    return {"status": "healthy"}
