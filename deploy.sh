#!/bin/bash

set -e

echo "🚀 开始部署快手金币统计系统..."

# 检查Docker是否安装
if ! command -v docker &> /dev/null; then
    echo "❌ Docker未安装，请先安装Docker"
    echo "📥 正在安装Docker..."
    curl -fsSL https://get.docker.com | bash -s docker
    systemctl start docker
    systemctl enable docker
fi

# 检查Docker Compose是否可用
if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
    echo "📥 安装Docker Compose..."
    curl -L "https://github.com/docker/compose/releases/download/v2.20.3/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
fi

# 设置变量
PROJECT_NAME="ks-coin-system"
GITHUB_BASE="https://raw.githubusercontent.com/qinghe126/ks-coin-system/main"

echo "📥 下载项目文件..."

# 创建项目目录
mkdir -p $PROJECT_NAME
cd $PROJECT_NAME

# 清理可能存在的旧文件
rm -f app.py requirements.txt docker-compose.yml Dockerfile
rm -rf templates

# 下载应用文件
echo "下载app.py..."
curl -sSL -o app.py "$GITHUB_BASE/app.py"
echo "下载requirements.txt..."
curl -sSL -o requirements.txt "$GITHUB_BASE/requirements.txt"

# 创建templates目录
mkdir -p templates
echo "下载HTML模板..."
curl -sSL -o templates/index.html "$GITHUB_BASE/templates/index.html"
curl -sSL -o templates/login.html "$GITHUB_BASE/templates/login.html"

# 创建Dockerfile
cat > Dockerfile << 'EOF'
FROM python:3.9-slim

WORKDIR /app

# 安装系统依赖
RUN apt-get update && apt-get install -y \
    gcc \
    g++ \
    curl \
    && rm -rf /var/lib/apt/lists/*

# 复制依赖文件
COPY requirements.txt .

# 安装Python依赖
RUN pip install --no-cache-dir -r requirements.txt

# 复制应用文件
COPY . .

# 创建数据目录
RUN mkdir -p /data

# 暴露端口
EXPOSE 5000

# 启动命令
CMD ["gunicorn", "-w", "4", "-b", "0.0.0.0:5000", "app:app"]
EOF

# 创建docker-compose.yml
cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  ks-coin-system:
    build: .
    container_name: ks-coin-system
    ports:
      - "5000:5000"
    volumes:
      - ./data:/app/data
    environment:
      - FLASK_ENV=production
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:5000/health"]
      interval: 30s
      timeout: 10s
      retries: 3
EOF

# 创建数据目录
mkdir -p data

echo "🐳 构建Docker镜像..."
if command -v docker-compose &> /dev/null; then
    docker-compose build
else
    docker compose build
fi

echo "🚀 启动服务..."
if command -v docker-compose &> /dev/null; then
    docker-compose up -d
else
    docker compose up -d
fi

echo "⏳ 等待服务启动..."
sleep 15

# 检查服务状态
if command -v docker-compose &> /dev/null; then
    if docker-compose ps | grep -q "Up"; then
        echo "✅ 部署成功！"
    else
        echo "❌ 服务启动失败，请检查日志"
        docker-compose logs
        exit 1
    fi
else
    if docker compose ps | grep -q "Up"; then
        echo "✅ 部署成功！"
    else
        echo "❌ 服务启动失败，请检查日志"
        docker compose logs
        exit 1
    fi
fi

# 获取服务器IP
SERVER_IP=$(curl -s ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}' || echo "localhost")

echo "📊 应用访问地址: http://${SERVER_IP}:5000"
echo "🔑 默认账号: admin / admin123"
echo ""
echo "📋 常用命令:"
echo "   查看日志: cd ks-coin-system && docker-compose logs -f"
echo "   停止服务: cd ks-coin-system && docker-compose down"
echo "   重启服务: cd ks-coin-system && docker-compose restart"
echo ""
echo "💾 数据保存在: $(pwd)/data 目录"
