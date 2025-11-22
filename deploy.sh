#!/bin/bash

# 快手金币统计系统一键部署脚本
# 适用于CentOS, Ubuntu等已安装Docker的Linux系统

set -e

echo "=========================================="
echo "快手金币统计系统 Docker 一键部署脚本"
echo "=========================================="

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查Docker是否安装
check_docker() {
    if ! command -v docker &> /dev/null; then
        log_error "Docker 未安装，请先安装Docker"
        exit 1
    fi
    
    if ! command -v docker-compose &> /dev/null; then
        log_warn "Docker Compose 未安装，将使用Docker命令替代"
    fi
    
    log_info "Docker 检查通过"
}

# 创建项目目录结构
create_directories() {
    log_info "创建项目目录结构..."
    
    mkdir -p /opt/ks-coin-system/{data,logs,backups}
    cd /opt/ks-coin-system
    
    log_info "项目目录创建完成: /opt/ks-coin-system"
}

# 下载项目文件
download_files() {
    log_info "从GitHub下载项目文件..."
    
    # 基础URL
    BASE_URL="https://raw.githubusercontent.com/qinghe126/ks-coin-system/main"
    
    # 下载应用文件
    curl -sSL -o app.py "$BASE_URL/app.py"
    curl -sSL -o requirements.txt "$BASE_URL/requirements.txt"
    
    # 创建templates目录并下载HTML文件
    mkdir -p templates
    curl -sSL -o templates/index.html "$BASE_URL/templates/index.html"
    curl -sSL -o templates/login.html "$BASE_URL/templates/login.html"
    
    # 创建Dockerfile
    cat > Dockerfile << 'EOF'
FROM python:3.9-slim

WORKDIR /app

# 安装系统依赖
RUN apt-get update && apt-get install -y \
    gcc \
    g++ \
    && rm -rf /var/lib/apt/lists/*

# 复制依赖文件
COPY requirements.txt .

# 安装Python依赖
RUN pip install --no-cache-dir -r requirements.txt

# 复制应用文件
COPY . .

# 创建数据目录
RUN mkdir -p /app/data

# 暴露端口
EXPOSE 5000

# 启动应用
CMD ["python", "app.py"]
EOF

    # 创建docker-compose.yml
    cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  ks-coin-system:
    build: .
    container_name: ks-coin-system
    restart: unless-stopped
    ports:
      - "5000:5000"
    volumes:
      - ./data:/app/data
      - ./logs:/app/logs
    environment:
      - TZ=Asia/Shanghai
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:5000/health"]
      interval: 30s
      timeout: 10s
      retries: 3
EOF

    # 创建启动脚本
    cat > start.sh << 'EOF'
#!/bin/bash

# 快手金币统计系统启动脚本

cd /opt/ks-coin-system

echo "启动快手金币统计系统..."

# 检查是否使用docker-compose
if command -v docker-compose &> /dev/null; then
    docker-compose up -d
else
    # 使用docker命令
    docker build -t ks-coin-system .
    docker run -d \
        --name ks-coin-system \
        --restart unless-stopped \
        -p 5000:5000 \
        -v /opt/ks-coin-system/data:/app/data \
        -v /opt/ks-coin-system/logs:/app/logs \
        -e TZ=Asia/Shanghai \
        ks-coin-system
fi

echo "系统启动完成!"
echo "访问地址: http://服务器IP:5000"
echo "默认账号: admin / admin123"
EOF

    chmod +x start.sh

    # 创建停止脚本
    cat > stop.sh << 'EOF'
#!/bin/bash

# 快手金币统计系统停止脚本

cd /opt/ks-coin-system

echo "停止快手金币统计系统..."

if command -v docker-compose &> /dev/null; then
    docker-compose down
else
    docker stop ks-coin-system
    docker rm ks-coin-system
fi

echo "系统已停止"
EOF

    chmod +x stop.sh

    # 创建更新脚本
    cat > update.sh << 'EOF'
#!/bin/bash

# 快手金币统计系统更新脚本

cd /opt/ks-coin-system

echo "更新快手金币统计系统..."

# 停止当前服务
./stop.sh

# 备份数据
BACKUP_DIR="backups/$(date +%Y%m%d_%H%M%S)"
mkdir -p $BACKUP_DIR
cp -r data/* $BACKUP_DIR/ 2>/dev/null || true

# 重新下载文件
BASE_URL="https://raw.githubusercontent.com/qinghe126/ks-coin-system/main"

curl -sSL -o app.py "$BASE_URL/app.py"
curl -sSL -o requirements.txt "$BASE_URL/requirements.txt"
curl -sSL -o templates/index.html "$BASE_URL/templates/index.html"
curl -sSL -o templates/login.html "$BASE_URL/templates/login.html"

# 重新启动
./start.sh

echo "系统更新完成!"
EOF

    chmod +x update.sh

    log_info "项目文件下载完成"
}

# 构建和启动容器
build_and_start() {
    log_info "开始构建Docker镜像..."
    
    cd /opt/ks-coin-system
    
    # 构建镜像
    docker build -t ks-coin-system .
    
    log_info "Docker镜像构建完成"
    
    log_info "启动容器..."
    ./start.sh
}

# 显示部署信息
show_deploy_info() {
    log_info "=========================================="
    log_info "部署完成!"
    log_info "=========================================="
    echo ""
    echo -e "${GREEN}系统信息:${NC}"
    echo "访问地址: http://你的服务器IP:5000"
    echo "默认账号: admin"
    echo "默认密码: admin123"
    echo ""
    echo -e "${GREEN}管理命令:${NC}"
    echo "启动系统: cd /opt/ks-coin-system && ./start.sh"
    echo "停止系统: cd /opt/ks-coin-system && ./stop.sh"
    echo "更新系统: cd /opt/ks-coin-system && ./update.sh"
    echo ""
    echo -e "${GREEN}数据目录:${NC}"
    echo "数据库文件: /opt/ks-coin-system/data/ks_data.db"
    echo "日志文件: /opt/ks-coin-system/logs/"
    echo "备份目录: /opt/ks-coin-system/backups/"
    echo ""
    echo -e "${YELLOW}安全提醒:${NC}"
    echo "1. 首次登录后请及时修改默认密码"
    echo "2. 建议配置防火墙，仅允许可信IP访问5000端口"
    echo "3. 定期备份 /opt/ks-coin-system/data/ 目录"
    echo ""
}

# 检查端口是否被占用
check_port() {
    if netstat -tuln | grep ':5000 ' > /dev/null; then
        log_warn "端口5000已被占用，尝试停止占用进程..."
        # 查找并停止占用5000端口的进程
        PID=$(lsof -ti:5000 2>/dev/null || echo "")
        if [ ! -z "$PID" ]; then
            kill -9 $PID
            sleep 2
        fi
    fi
}

# 主部署函数
main_deploy() {
    log_info "开始部署快手金币统计系统..."
    
    # 执行部署步骤
    check_docker
    check_port
    create_directories
    download_files
    build_and_start
    show_deploy_info
    
    log_info "部署脚本执行完毕!"
}

# 执行主函数
main_deploy
