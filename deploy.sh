# 创建优化后的部署脚本
cat > deploy_optimized.sh << 'EOF'
#!/bin/bash

# 快手金币统计系统一键部署脚本 - 优化内存版本
# 适用于CentOS, Ubuntu等已安装Docker的Linux系统

set -e

echo "=========================================="
echo "快手金币统计系统 Docker 一键部署脚本"
echo "=========================================="

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

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
    
    if systemctl is-active --quiet docker; then
        log_info "Docker 服务正在运行"
    else
        log_info "启动Docker服务..."
        systemctl start docker
        systemctl enable docker
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
    log_info "下载项目文件..."
    
    # 基础URL
    BASE_URL="https://raw.githubusercontent.com/qinghe126/ks-coin-system/main"
    
    # 下载应用文件
    curl -sSL -o app.py "$BASE_URL/app.py"
    curl -sSL -o requirements.txt "$BASE_URL/requirements.txt"
    
    # 创建templates目录并下载HTML文件
    mkdir -p templates
    curl -sSL -o templates/index.html "$BASE_URL/templates/index.html"
    curl -sSL -o templates/login.html "$BASE_URL/templates/login.html"
    
    # 创建优化的Dockerfile - 减少内存使用
    cat > Dockerfile << 'DOCKERFILEEOF'
FROM python:3.9-alpine

WORKDIR /app

# 安装系统依赖 - Alpine版本，更轻量
RUN apk update && apk add --no-cache \
    gcc \
    musl-dev \
    linux-headers \
    && rm -rf /var/cache/apk/*

# 复制依赖文件
COPY requirements.txt .

# 安装Python依赖 - 使用国内镜像加速
RUN pip install --no-cache-dir -r requirements.txt -i https://pypi.tuna.tsinghua.edu.cn/simple

# 复制应用文件
COPY . .

# 创建数据目录
RUN mkdir -p /app/data

# 暴露端口
EXPOSE 5000

# 启动应用
CMD ["python", "app.py"]
DOCKERFILEEOF

    # 创建docker-compose.yml
    cat > docker-compose.yml << 'COMPOSEEOF'
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
    mem_limit: 512m
    mem_reservation: 256m
COMPOSEEOF

    # 创建启动脚本
    cat > start.sh << 'STARTEOF'
#!/bin/bash

cd /opt/ks-coin-system

echo "启动快手金币统计系统..."

# 停止已存在的容器
docker stop ks-coin-system 2>/dev/null || true
docker rm ks-coin-system 2>/dev/null || true

# 构建镜像（使用更少内存的方式）
echo "构建Docker镜像（优化内存版本）..."
docker build --memory=512m --memory-swap=1g -t ks-coin-system .

# 启动新容器
docker run -d \
    --name ks-coin-system \
    --restart unless-stopped \
    -p 5000:5000 \
    -v /opt/ks-coin-system/data:/app/data \
    -v /opt/ks-coin-system/logs:/app/logs \
    -e TZ=Asia/Shanghai \
    --memory=512m \
    --memory-swap=1g \
    ks-coin-system

echo "系统启动完成!"
echo "访问地址: http://服务器IP:5000"
echo "默认账号: admin / admin123"
STARTEOF

    chmod +x start.sh

    # 创建停止脚本
    cat > stop.sh << 'STOPEOF'
#!/bin/bash

cd /opt/ks-coin-system

echo "停止快手金币统计系统..."

docker stop ks-coin-system 2>/dev/null || true
docker rm ks-coin-system 2>/dev/null || true

echo "系统已停止"
STOPEOF

    chmod +x stop.sh

    # 创建重启脚本
    cat > restart.sh << 'RESTARTEOF'
#!/bin/bash

cd /opt/ks-coin-system
./stop.sh
sleep 2
./start.sh
RESTARTEOF

    chmod +x restart.sh

    log_info "项目文件下载完成"
}

# 检查系统资源
check_resources() {
    log_info "检查系统资源..."
    
    # 检查内存
    total_mem=$(free -m | awk 'NR==2{print $2}')
    available_mem=$(free -m | awk 'NR==2{print $7}')
    
    log_info "总内存: ${total_mem}MB"
    log_info "可用内存: ${available_mem}MB"
    
    if [ "$available_mem" -lt "512" ]; then
        log_warn "可用内存较少，建议增加系统内存或交换空间"
    fi
    
    # 检查磁盘空间
    disk_space=$(df /opt/ks-coin-system | awk 'NR==2{print $4}')
    log_info "可用磁盘空间: ${disk_space}"
}

# 构建和启动容器
build_and_start() {
    log_info "开始构建Docker镜像（优化内存版本）..."
    
    cd /opt/ks-coin-system
    
    # 使用优化参数构建镜像
    ./start.sh
}

# 显示部署信息
show_deploy_info() {
    log_info "=========================================="
    log_info "部署完成!"
    log_info "=========================================="
    echo ""
    echo -e "${GREEN}系统信息:${NC}"
    echo "访问地址: http://$(curl -s ifconfig.me 2>/dev/null || echo "服务器IP"):5000"
    echo "默认账号: admin"
    echo "默认密码: admin123"
    echo ""
    echo -e "${GREEN}管理命令:${NC}"
    echo "启动系统: cd /opt/ks-coin-system && ./start.sh"
    echo "停止系统: cd /opt/ks-coin-system && ./stop.sh"
    echo "重启系统: cd /opt/ks-coin-system && ./restart.sh"
    echo "查看日志: docker logs ks-coin-system"
    echo ""
    echo -e "${YELLOW}安全提醒:${NC}"
    echo "1. 首次登录后请及时在代码中修改默认密码"
    echo "2. 建议配置防火墙，仅允许可信IP访问5000端口"
    echo "3. 定期备份 /opt/ks-coin-system/data/ 目录"
    echo ""
}

# 检查端口是否被占用
check_port() {
    if netstat -tuln 2>/dev/null | grep ':5000 ' > /dev/null; then
        log_warn "端口5000已被占用"
        PID=$(lsof -ti:5000 2>/dev/null || echo "")
        if [ ! -z "$PID" ]; then
            log_info "停止占用进程: $PID"
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
    check_resources
    check_port
    create_directories
    download_files
    build_and_start
    show_deploy_info
    
    log_info "部署脚本执行完毕!"
}

# 执行主函数
main_deploy
EOF

chmod +x deploy_optimized.sh
./deploy_optimized.sh
