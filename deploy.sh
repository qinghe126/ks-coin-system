#!/bin/bash

# 简化版部署脚本
set -e

echo "🚀 快手金币统计系统一键部署"

# 安装Docker（如果未安装）
if ! command -v docker &> /dev/null; then
    echo "安装Docker..."
    curl -fsSL https://get.docker.com | bash
    systemctl start docker
    systemctl enable docker
fi

# 创建项目目录
mkdir -p ks-coin-system
cd ks-coin-system

# 下载文件
curl -sSL -o app.py https://raw.githubusercontent.com/qinghe126/ks-coin-system/main/app.py
curl -sSL -o requirements.txt https://raw.githubusercontent.com/qinghe126/ks-coin-system/main/requirements.txt
mkdir -p templates
curl -sSL -o templates/index.html https://raw.githubusercontent.com/qinghe126/ks-coin-system/main/templates/index.html
curl -sSL -o templates/login.html https://raw.githubusercontent.com/qinghe126/ks-coin-system/main/templates/login.html

# 创建Dockerfile
cat > Dockerfile << 'EOF'
FROM python:3.9-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install -r requirements.txt
COPY . .
EXPOSE 5000
CMD ["python", "app.py"]
EOF

# 创建docker-compose.yml
cat > docker-compose.yml << 'EOF'
version: '3'
services:
  ks-coin-system:
    build: .
    ports:
      - "5000:5000"
    volumes:
      - ./data:/app/data
    restart: unless-stopped
EOF

# 启动服务
docker-compose up -d

echo "✅ 部署完成！访问地址: http://服务器IP:5000"
echo "默认账号: admin / admin123"
