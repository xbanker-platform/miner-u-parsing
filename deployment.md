# Install MinerU

## Create an environment
conda create -n MinerU python=3.10
conda activate MinerU
pip install -U magic-pdf[full] --extra-index-url https://wheels.myhloli.com

## Download model weight files
pip install huggingface_hub
wget https://github.com/opendatalab/MinerU/raw/master/scripts/download_models_hf.py -O download_models_hf.py
python download_models_hf.py

## Install LibreOffice[Optional]
## This section is required for handle doc, docx, ppt, pptx filetype, You can skip this section if no need for those filetype processing.

## Linux/Macos Platform

apt-get/yum/brew install libreoffice

## Windows Platform

install libreoffice
append "install_dir\LibreOffice\program" to ENVIRONMENT PATH

## Boost With Cuda

Ubuntu 22.04 LTS
1. Check if NVIDIA Drivers Are Installed
nvidia-smi
If you see information similar to the following, it means that the NVIDIA drivers are already installed, and you can skip Step 2.

Note

CUDA Version should be >= 12.1, If the displayed version number is less than 12.1, please upgrade the driver.

+---------------------------------------------------------------------------------------+
| NVIDIA-SMI 537.34                 Driver Version: 537.34       CUDA Version: 12.2     |
|-----------------------------------------+----------------------+----------------------+
| GPU  Name                     TCC/WDDM  | Bus-Id        Disp.A | Volatile Uncorr. ECC |
| Fan  Temp   Perf          Pwr:Usage/Cap |         Memory-Usage | GPU-Util  Compute M. |
|                                         |                      |               MIG M. |
|=========================================+======================+======================|
|   0  NVIDIA GeForce RTX 3060 Ti   WDDM  | 00000000:01:00.0  On |                  N/A |
|  0%   51C    P8              12W / 200W |   1489MiB /  8192MiB |      5%      Default |
|                                         |                      |                  N/A |
+-----------------------------------------+----------------------+----------------------+
2. Install the Driver
If no driver is installed, use the following command:

sudo apt-get update
sudo apt-get install nvidia-driver-545
Install the proprietary driver and restart your computer after installation.

reboot
3. Install Anaconda
If Anaconda is already installed, skip this step.

wget https://repo.anaconda.com/archive/Anaconda3-2024.06-1-Linux-x86_64.sh
bash Anaconda3-2024.06-1-Linux-x86_64.sh
In the final step, enter yes, close the terminal, and reopen it.

4. Create an Environment Using Conda
Specify Python version 3.10.

conda create -n MinerU python=3.10
conda activate MinerU
5. Install Applications
pip install -U magic-pdf[full] --extra-index-url https://wheels.myhloli.com
Important

❗ After installation, make sure to check the version of magic-pdf using the following command:

magic-pdf --version
If the version number is less than 0.7.0, please report the issue.

6. Download Models
Refer to detailed instructions on Download Model Weight Files

7. Understand the Location of the Configuration File
After completing the 6. Download Models step, the script will automatically generate a magic-pdf.json file in the user directory and configure the default model path. You can find the magic-pdf.json file in your user directory.

TIP

The user directory for Linux is “/home/username”.

8. First Run
Download a sample file from the repository and test it.

wget https://github.com/opendatalab/MinerU/raw/master/demo/small_ocr.pdf
magic-pdf -p small_ocr.pdf -o ./output
9. Test CUDA Acceleration
If your graphics card has at least 8GB of VRAM, follow these steps to test CUDA acceleration:

Modify the value of "device-mode" in the magic-pdf.json configuration file located in your home directory.

{
  "device-mode": "cuda"
}
Test CUDA acceleration with the following command:

magic-pdf -p small_ocr.pdf -o ./output
10. Enable CUDA Acceleration for OCR
Download paddlepaddle-gpu. Installation will automatically enable OCR acceleration.

python -m pip install paddlepaddle-gpu==3.0.0b1 -i https://www.paddlepaddle.org.cn/packages/stable/cu118/
Test OCR acceleration with the following command:

magic-pdf -p small_ocr.pdf -o ./output

Download Model Weight Files
Model downloads are divided into initial downloads and updates to the model directory. Please refer to the corresponding documentation for instructions on how to proceed.

Initial download of model files
1. Download the Model from Hugging Face
Use a Python Script to Download Model Files from Hugging Face

pip install huggingface_hub
wget https://github.com/opendatalab/MinerU/raw/master/scripts/download_models_hf.py -O download_models_hf.py
python download_models_hf.py
The Python script will automatically download the model files and configure the model directory in the configuration file.

The configuration file can be found in the user directory, with the filename magic-pdf.json.

Config
File magic-pdf.json is typically located in the ${HOME} directory under a Linux system or in the C:Users{username} directory under a Windows system.

Tip

You can override the default location of config file via the following command:

export MINERU_TOOLS_CONFIG_JSON=new_magic_pdf.json

magic-pdf.json
{
    "bucket_info":{
        "bucket-name-1":["ak", "sk", "endpoint"],
        "bucket-name-2":["ak", "sk", "endpoint"]
    },
    "models-dir":"/tmp/models",
    "layoutreader-model-dir":"/tmp/layoutreader",
    "device-mode":"cpu",
    "layout-config": {
        "model": "layoutlmv3"
    },
    "formula-config": {
        "mfd_model": "yolo_v8_mfd",
        "mfr_model": "unimernet_small",
        "enable": true
    },
    "table-config": {
        "model": "rapid_table",
        "enable": false,
        "max_time": 400
    },
    "config_version": "1.0.0"
}
bucket_info
Store the access_key, secret_key and endpoint of AWS S3 Compatible storage config

Example:

{
    "image_bucket":[{access_key}, {secret_key}, {endpoint}],
    "video_bucket":[{access_key}, {secret_key}, {endpoint}]
}
models-dir
Store the models download from huggingface or modelshop. You do not need to modify this field if you download the model using the scripts shipped with MinerU

layoutreader-model-dir
Store the models download from huggingface or modelshop. You do not need to modify this field if you download the model using the scripts shipped with MinerU

devide-mode
This field have two options, cpu or cuda.

cpu: inference via cpu

cuda: using cuda to accelerate inference

layout-config
{
    "model": "layoutlmv3"
}
layout model can not be disabled now, And we have only kind of layout model currently.

formula-config
{
    "mfd_model": "yolo_v8_mfd",
    "mfr_model": "unimernet_small",
    "enable": true
}
mfd_model
Specify the formula detection model, options are [‘yolo_v8_mfd’]

mfr_model
Specify the formula recognition model, options are [‘unimernet_small’]

Check UniMERNet for more details

enable
on-off flag, options are [true, false]. true means enable formula inference, false means disable formula inference

table-config
{
     "model": "rapid_table",
     "enable": false,
     "max_time": 400
 }
model
Specify the table inference model, options are [‘rapid_table’, ‘tablemaster’, ‘struct_eqtable’]

max_time
Since table recognition is a time-consuming process, we set a timeout period. If the process exceeds this time, the table recognition will be terminated.

enable
on-off flag, options are [true, false]. true means enable table inference, false means disable table inference


Docker
Important

Docker requires a GPU with at least 16GB of VRAM, and all acceleration features are enabled by default.

Before running this Docker, you can use the following command to check if your device supports CUDA acceleration on Docker.

bash  docker run --rm --gpus=all nvidia/cuda:12.1.0-base-ubuntu22.04 nvidia-smi
wget https://github.com/opendatalab/MinerU/raw/master/Dockerfile
docker build -t mineru:latest .
docker run --rm -it --gpus=all mineru:latest /bin/bash
magic-pdf --help