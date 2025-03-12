class Config:
    # AWS凭证
    aws_access_key_id = "YOUR_AWS_ACCESS_KEY_ID"
    aws_secret_access_key = "YOUR_AWS_SECRET_ACCESS_KEY"
    
    # S3桶配置
    s3_bucket_name = "file_temp"
    s3_region = "ap-southeast-2"
    
    # API Gateway配置
    api_gateway_url = "https://q4fu70mx53.execute-api.ap-southeast-2.amazonaws.com/upkgdto"
    
    # 任务处理配置
    max_concurrent_tasks = 4
    default_priority = "normal" 