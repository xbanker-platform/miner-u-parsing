import logging
import json
import requests
from config import Config

class ApiGatewayClient:
    def __init__(self, api_url):
        self.api_url = api_url
        
    def notify_processing_result(self, task_id, success, bucket_name, file_keys, error_message=None):
        """
        通知API Gateway处理结果
        
        Args:
            task_id: 任务ID
            success: 处理是否成功
            bucket_name: S3桶名称
            file_keys: 处理结果文件的键列表
            error_message: 错误信息（如果处理失败）
            
        Returns:
            bool: 通知是否成功
        """
        payload = {
            "task_id": task_id,
            "success": success,
            "bucket_name": bucket_name,
            "file_keys": file_keys
        }
        
        if error_message:
            payload["error_message"] = error_message
            
        try:
            response = requests.post(
                self.api_url,
                json=payload,
                headers={"Content-Type": "application/json"}
            )
            
            if response.status_code == 200:
                logging.info({
                    "message": f"Successfully notified API Gateway for task {task_id}"
                })
                return True
            else:
                logging.error({
                    "message": f"Failed to notify API Gateway for task {task_id}. Status code: {response.status_code}, Response: {response.text}"
                })
                return False
                
        except Exception as e:
            logging.error({
                "message": f"Exception when notifying API Gateway for task {task_id}: {str(e)}"
            })
            return False

_api_gateway_client = None

def get_api_gateway_client():
    global _api_gateway_client
    if _api_gateway_client is None:
        _api_gateway_client = ApiGatewayClient(Config.api_gateway_url)
    return _api_gateway_client 