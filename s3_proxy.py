import logging
import boto3
from botocore.exceptions import NoCredentialsError, ClientError

from config import Config

class S3Proxy:
    def __init__(self, aws_access_key_id, aws_secret_access_key, region_name):
        self.s3_client = boto3.client(
            's3',
            aws_access_key_id=aws_access_key_id,
            aws_secret_access_key=aws_secret_access_key,
            region_name=region_name
        )

    def upload_file(self, file_name, bucket, object_name=None):
        """Upload a file to an S3 bucket"""
        if object_name is None:
            object_name = file_name
        try:
            self.s3_client.upload_file(file_name, bucket, object_name)
            logging.info({
                'message': f"File {file_name} uploaded to {bucket}/{object_name}"
            })
            return True
        except FileNotFoundError:
            logging.error({
                'message': f"The file {file_name} was not found"
            })
            return False
        except NoCredentialsError:
            logging.error({
                'message': "Credentials not available"
            })
            return False
        except ClientError as e:
            logging.error({
                'message': f"Failed to upload {file_name}: {e}"
            })
            return False

    def object_exists(self, bucket, object_name):
        """Check if an object exists in an S3 bucket"""
        try:
            self.s3_client.head_object(Bucket=bucket, Key=object_name)
            logging.info({
                'message': f"Object {object_name} exists in bucket {bucket}"
            })
            return True
        except ClientError as e:
            if e.response['Error']['Code'] == '404':
                logging.info({
                    'message': f"Object {object_name} does not exist in bucket {bucket}"
                })
                return False
            else:
                logging.error({
                    'message': f"Failed to check existence of {object_name}: {e}"
                })
                return False
                
    def download_file(self, bucket, object_name, file_name=None):
        """Download a file from an S3 bucket"""
        if file_name is None:
            file_name = object_name

        try:
            self.s3_client.download_file(bucket, object_name, file_name)
            logging.info({
                'message': f"File {object_name} downloaded from {bucket} to {file_name}"
            })
            return True
        except NoCredentialsError:
             logging.error({
                'message': f"Failed to download {object_name}: Credentials not available"
            })
             return False
        except ClientError as e:
             logging.error({
                'message': f"Failed to download {object_name}: {e}"
            })
             return False

    def list_files(self, bucket):
        """List files in an S3 bucket"""
        try:
            response = self.s3_client.list_objects_v2(Bucket=bucket)
            files = []
            if 'Contents' in response:
                for obj in response['Contents']:
                    files.append(obj['Key'])
                    logging.info({
                        'message': f"File found: {obj['Key']}"
                    })
            else:
                logging.info({
                    'message': f"No files found in bucket {bucket}"
                })
            return files
        except ClientError as e:
            logging.error({
                'message': f"Failed to list files in {bucket}: {e}"
            })
            return []

    def get_object_content(self, bucket, object_name):
        """Get the content of an object from an S3 bucket"""
        try:
            response = self.s3_client.get_object(Bucket=bucket, Key=object_name)
            content = response['Body'].read()
            logging.info({
                'message': f"Content retrieved from {object_name} in {bucket}"
            })
            return content
        except NoCredentialsError:
            logging.error({
                'message': "Credentials not available"
            })
            return None
        except ClientError as e:
            logging.error({
                'message': f"Failed to get content of {object_name}: {e}"
            })
            return None

    def delete_file(self, bucket, object_name):
        """Delete a file from an S3 bucket"""
        try:
            self.s3_client.delete_object(Bucket=bucket, Key=object_name)
            logging.info({
                'message': f"File {object_name} deleted from {bucket}"
            })
            return True
        except NoCredentialsError:
            logging.error({
                'message': "Credentials not available"
            })
            return False
        except ClientError as e:
            logging.error({
                'message': f"Failed to delete {object_name}: {e}"
            })
            return False

    def upload_object(self, object_data, bucket, object_name):
        """Upload an object to an S3 bucket"""
        try:
            self.s3_client.put_object(Body=object_data, Bucket=bucket, Key=object_name)
            logging.info({
                'message': f"Object {object_name} uploaded to {bucket}"
            })  
            return True
        except NoCredentialsError:
            logging.error({
                'message': "Credentials not available"
            })
            return False
        except ClientError as e:
            logging.error({
                'message': f"Failed to upload object {object_name}: {e}"
            })
            return False

    def check_object_exists(self, bucket, key):
        """
        检查S3对象是否存在
        Args:
            bucket: 桶名
            key: 对象键
        Returns:
            bool: 对象是否存在
        """
        try:
            self.s3_client.head_object(Bucket=bucket, Key=key)
            return True
        except Exception as e:
            # 如果对象不存在，会抛出异常
            return False

_oss_instance = None

def get_oss_instance(region_name='ap-southeast-2'):
    global _oss_instance
    if _oss_instance is None:
        _oss_instance = S3Proxy(Config.aws_access_key_id, Config.aws_secret_access_key, region_name)
    return _oss_instance 