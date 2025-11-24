# 创建使用国内镜像源的部署脚本
cat > deploy_china.sh << 'EOF'
#!/bin/bash

# 快手金币统计系统一键部署脚本 - 国内镜像优化版

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
    
    # 创建使用国内镜像的Dockerfile
    cat > Dockerfile << 'DOCKERFILEEOF'
FROM python:3.9-slim

WORKDIR /app

# 使用国内APT镜像源和PyPI镜像
RUN sed -i 's/deb.debian.org/mirrors.aliyun.com/g' /etc/apt/sources.list && \
    sed -i 's/security.debian.org/mirrors.aliyun.com/g' /etc/apt/sources.list && \
    apt-get update && \
    apt-get install -y --no-install-recommends gcc g++ && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# 复制依赖文件
COPY requirements.txt .

# 使用国内PyPI镜像安装依赖
RUN pip install --no-cache-dir -r requirements.txt -i https://pypi.tuna.tsinghua.edu.cn/simple --trusted-host pypi.tuna.tsinghua.edu.cn

# 复制应用文件
COPY . .

# 创建数据目录
RUN mkdir -p /app/data

# 暴露端口
EXPOSE 5000

# 启动应用
CMD ["python", "app.py"]
DOCKERFILEEOF

    # 创建启动脚本
    cat > start.sh << 'STARTEOF'
#!/bin/bash

cd /opt/ks-coin-system

echo "启动快手金币统计系统..."

# 停止已存在的容器
docker stop ks-coin-system 2>/dev/null || true
docker rm ks-coin-system 2>/dev/null || true

# 构建镜像
echo "构建Docker镜像..."
docker build -t ks-coin-system .

# 启动新容器
docker run -d \
    --name ks-coin-system \
    --restart unless-stopped \
    -p 5000:5000 \
    -v /opt/ks-coin-system/data:/app/data \
    -v /opt/ks-coin-system/logs:/app/logs \
    -e TZ=Asia/Shanghai \
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

    log_info "项目文件下载完成"
}

# 检查系统资源
check_resources() {
    log_info "检查系统资源..."
    
    # 检查内存
    total_mem=$(free -m 2>/dev/null | awk 'NR==2{print $2}' || echo "未知")
    available_mem=$(free -m 2>/dev/null | awk 'NR==2{print $7}' || echo "未知")
    
    log_info "总内存: ${total_mem}MB"
    log_info "可用内存: ${available_mem}MB"
    
    # 检查磁盘空间
    disk_space=$(df /opt/ks-coin-system 2>/dev/null | awk 'NR==2{print $4}' || echo "未知")
    log_info "可用磁盘空间: ${disk_space}"
}

# 构建和启动容器
build_and_start() {
    log_info "开始构建Docker镜像..."
    
    cd /opt/ks-coin-system
    
    # 构建镜像
    ./start.sh
}

# 显示部署信息
show_deploy_info() {
    log_info "=========================================="
    log_info "部署完成!"
    log_info "=========================================="
    echo ""
    echo -e "${GREEN}系统信息:${NC}"
    
    # 获取服务器IP
    SERVER_IP=$(curl -s ifconfig.me 2>/dev/null || hostname -I 2>/dev/null | awk '{print $1}' || echo "服务器IP")
    echo "访问地址: http://${SERVER_IP}:5000"
    echo "默认账号: admin"
    echo "默认密码: admin123"
    echo ""
    echo -e "${GREEN}管理命令:${NC}"
    echo "启动系统: cd /opt/ks-coin-system && ./start.sh"
    echo "停止系统: cd /opt/ks-coin-system && ./stop.sh"
    echo "查看日志: docker logs ks-coin-system"
    echo "查看状态: docker ps | grep ks-coin-system"
    echo ""
    echo -e "${YELLOW}安全提醒:${NC}"
    echo "1. 首次登录后请及时修改默认密码"
    echo "2. 建议配置防火墙，仅允许可信IP访问5000端口"
    echo "3. 定期备份 /opt/ks-coin-system/data/ 目录"
    echo ""
}

# 检查端口是否被占用
check_port() {
    if command -v netstat &> /dev/null && netstat -tuln 2>/dev/null | grep ':5000 ' > /dev/null; then
        log_warn "端口5000已被占用"
        PID=$(lsof -ti:5000 2>/dev/null || echo "")
        if [ ! -z "$PID" ]; then
            log_info "停止占用进程: $PID"
            kill -9 $PID
            sleep 2
        fi
    elif command -v ss &> /dev/null && ss -tuln 2>/dev/null | grep ':5000 ' > /dev/null; then
        log_warn "端口5000已被占用"
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
    
    # 等待容器启动
    sleep 5
    
    # 检查容器状态
    if docker ps | grep -q ks-coin-system; then
        show_deploy_info
    else
        log_error "容器启动失败，请检查日志: docker logs ks-coin-system"
        exit 1
    fi
    
    log_info "部署脚本执行完毕!"
}

# 执行主函数
main_deploy
EOF

chmod +x deploy_china.sh
./deploy_china.sh
