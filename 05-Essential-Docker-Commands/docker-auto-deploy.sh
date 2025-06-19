#!/bin/bash

# Docker 自动化部署脚本
# 作者：Grissom
# 用途：提供常见应用的一键部署功能

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 全局变量
DEPLOY_DIR="$HOME/docker-deployments"
LOG_FILE="$DEPLOY_DIR/deployment.log"

# 工具函数
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

print_header() {
    echo -e "\n${PURPLE}=== $1 ===${NC}"
    log_message "开始部署：$1"
}

print_step() {
    echo -e "${CYAN}步骤 $1：${NC}$2"
    log_message "步骤 $1：$2"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
    log_message "成功：$1"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
    log_message "错误：$1"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
    log_message "警告：$1"
}

# 检查依赖
check_dependencies() {
    print_step "1" "检查依赖"
    
    if ! command -v docker &> /dev/null; then
        print_error "Docker 未安装"
        exit 1
    fi
    
    if ! docker info &> /dev/null; then
        print_error "Docker 服务未运行"
        exit 1
    fi
    
    print_success "依赖检查通过"
}

# 创建部署目录
setup_deploy_directory() {
    mkdir -p "$DEPLOY_DIR"/{nginx,mysql,redis,mongodb,postgres,wordpress,nextcloud,gitlab,jenkins,portainer}
    mkdir -p "$DEPLOY_DIR/logs"
    touch "$LOG_FILE"
}

# 部署 Nginx Web 服务器
deploy_nginx() {
    print_header "部署 Nginx Web 服务器"
    
    local nginx_dir="$DEPLOY_DIR/nginx"
    cd "$nginx_dir"
    
    print_step "2" "创建 Nginx 配置"
    cat > nginx.conf << 'EOF'
user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log warn;
pid /var/run/nginx.pid;

events {
    worker_connections 1024;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;
    
    log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                    '$status $body_bytes_sent "$http_referer" '
                    '"$http_user_agent" "$http_x_forwarded_for"';
    
    access_log /var/log/nginx/access.log main;
    
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;
    
    server {
        listen 80;
        server_name localhost;
        root /usr/share/nginx/html;
        index index.html index.htm;
        
        location / {
            try_files $uri $uri/ =404;
        }
        
        error_page 404 /404.html;
        error_page 500 502 503 504 /50x.html;
        location = /50x.html {
            root /usr/share/nginx/html;
        }
    }
}
EOF

    cat > index.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Nginx Docker 部署成功</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; background: #f5f5f5; }
        .container { max-width: 800px; margin: 0 auto; background: white; padding: 40px; border-radius: 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        .header { text-align: center; color: #2c3e50; }
        .success { color: #27ae60; font-size: 24px; }
        .info { background: #ecf0f1; padding: 20px; border-radius: 5px; margin: 20px 0; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🚀 Nginx 部署成功！</h1>
            <p class="success">您的 Nginx 服务器正在运行</p>
        </div>
        <div class="info">
            <h3>服务信息</h3>
            <p><strong>服务器：</strong>Nginx (Docker)</p>
            <p><strong>端口：</strong>8080</p>
            <p><strong>状态：</strong>运行中</p>
            <p><strong>部署时间：</strong><span id="time"></span></p>
        </div>
    </div>
    <script>
        document.getElementById('time').textContent = new Date().toLocaleString();
    </script>
</body>
</html>
EOF

    print_step "3" "启动 Nginx 容器"
    docker run -d \
        --name nginx-server \
        -p 8080:80 \
        -v "$nginx_dir/nginx.conf:/etc/nginx/nginx.conf:ro" \
        -v "$nginx_dir/index.html:/usr/share/nginx/html/index.html:ro" \
        -v "$DEPLOY_DIR/logs:/var/log/nginx" \
        --restart unless-stopped \
        nginx:alpine
    
    print_success "Nginx 部署完成"
    print_info "访问地址：http://localhost:8080"
}

# 部署 MySQL 数据库
deploy_mysql() {
    print_header "部署 MySQL 数据库"
    
    local mysql_dir="$DEPLOY_DIR/mysql"
    cd "$mysql_dir"
    
    # 获取用户输入
    read -p "请输入 MySQL root 密码 [默认: rootpass]: " root_password
    root_password=${root_password:-rootpass}
    
    read -p "请输入数据库名称 [默认: testdb]: " database_name
    database_name=${database_name:-testdb}
    
    read -p "请输入用户名 [默认: testuser]: " username
    username=${username:-testuser}
    
    read -p "请输入用户密码 [默认: testpass]: " user_password
    user_password=${user_password:-testpass}
    
    print_step "2" "创建初始化脚本"
    cat > init.sql << EOF
CREATE DATABASE IF NOT EXISTS ${database_name};
CREATE USER IF NOT EXISTS '${username}'@'%' IDENTIFIED BY '${user_password}';
GRANT ALL PRIVILEGES ON ${database_name}.* TO '${username}'@'%';
FLUSH PRIVILEGES;

USE ${database_name};

CREATE TABLE IF NOT EXISTS users (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    email VARCHAR(100) NOT NULL UNIQUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO users (name, email) VALUES 
('张三', 'zhangsan@example.com'),
('李四', 'lisi@example.com'),
('王五', 'wangwu@example.com');
EOF

    print_step "3" "启动 MySQL 容器"
    docker run -d \
        --name mysql-server \
        -p 3306:3306 \
        -e MYSQL_ROOT_PASSWORD="$root_password" \
        -e MYSQL_DATABASE="$database_name" \
        -e MYSQL_USER="$username" \
        -e MYSQL_PASSWORD="$user_password" \
        -v "$mysql_dir/init.sql:/docker-entrypoint-initdb.d/init.sql" \
        -v mysql-data:/var/lib/mysql \
        --restart unless-stopped \
        mysql:8.0
    
    print_step "4" "等待 MySQL 启动"
    sleep 10
    
    print_success "MySQL 部署完成"
    print_info "连接信息："
    echo "  主机: localhost"
    echo "  端口: 3306"
    echo "  数据库: $database_name"
    echo "  用户名: $username"
    echo "  密码: $user_password"
    echo "  Root 密码: $root_password"
}

# 部署 Redis 缓存
deploy_redis() {
    print_header "部署 Redis 缓存服务"
    
    local redis_dir="$DEPLOY_DIR/redis"
    cd "$redis_dir"
    
    print_step "2" "创建 Redis 配置"
    cat > redis.conf << 'EOF'
# Redis 配置文件
bind 0.0.0.0
port 6379
timeout 0
tcp-keepalive 300

# 持久化配置
save 900 1
save 300 10
save 60 10000

# 日志配置
loglevel notice
logfile ""

# 内存配置
maxmemory 256mb
maxmemory-policy allkeys-lru

# 安全配置
# requirepass yourpassword
EOF

    print_step "3" "启动 Redis 容器"
    docker run -d \
        --name redis-server \
        -p 6379:6379 \
        -v "$redis_dir/redis.conf:/usr/local/etc/redis/redis.conf" \
        -v redis-data:/data \
        --restart unless-stopped \
        redis:alpine redis-server /usr/local/etc/redis/redis.conf
    
    print_success "Redis 部署完成"
    print_info "连接信息："
    echo "  主机: localhost"
    echo "  端口: 6379"
    echo "  测试命令: docker exec redis-server redis-cli ping"
}

# 部署 WordPress
deploy_wordpress() {
    print_header "部署 WordPress 博客系统"
    
    local wp_dir="$DEPLOY_DIR/wordpress"
    cd "$wp_dir"
    
    print_step "2" "创建 docker-compose.yml"
    cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  wordpress:
    image: wordpress:latest
    ports:
      - "8081:80"
    environment:
      WORDPRESS_DB_HOST: db:3306
      WORDPRESS_DB_USER: wordpress
      WORDPRESS_DB_PASSWORD: wordpress_pass
      WORDPRESS_DB_NAME: wordpress
    volumes:
      - wordpress_data:/var/www/html
    depends_on:
      - db
    restart: unless-stopped

  db:
    image: mysql:8.0
    environment:
      MYSQL_DATABASE: wordpress
      MYSQL_USER: wordpress
      MYSQL_PASSWORD: wordpress_pass
      MYSQL_ROOT_PASSWORD: root_pass
    volumes:
      - db_data:/var/lib/mysql
    restart: unless-stopped

volumes:
  wordpress_data:
  db_data:
EOF

    print_step "3" "启动 WordPress 服务"
    if command -v docker-compose &> /dev/null; then
        docker-compose up -d
        print_success "WordPress 部署完成"
        print_info "访问地址：http://localhost:8081"
        print_info "数据库信息："
        echo "  数据库名: wordpress"
        echo "  用户名: wordpress"
        echo "  密码: wordpress_pass"
    else
        print_error "docker-compose 未安装，无法部署 WordPress"
    fi
}

# 部署 Portainer (Docker 管理界面)
deploy_portainer() {
    print_header "部署 Portainer Docker 管理界面"
    
    print_step "2" "启动 Portainer 容器"
    docker run -d \
        --name portainer \
        -p 9000:9000 \
        -v /var/run/docker.sock:/var/run/docker.sock \
        -v portainer_data:/data \
        --restart unless-stopped \
        portainer/portainer-ce:latest
    
    print_success "Portainer 部署完成"
    print_info "访问地址：http://localhost:9000"
    print_info "首次访问需要设置管理员密码"
}

# 部署 Jenkins CI/CD
deploy_jenkins() {
    print_header "部署 Jenkins CI/CD 服务"
    
    local jenkins_dir="$DEPLOY_DIR/jenkins"
    mkdir -p "$jenkins_dir"
    
    print_step "2" "启动 Jenkins 容器"
    docker run -d \
        --name jenkins \
        -p 8082:8080 \
        -p 50000:50000 \
        -v jenkins_data:/var/jenkins_home \
        -v /var/run/docker.sock:/var/run/docker.sock \
        --restart unless-stopped \
        jenkins/jenkins:lts
    
    print_step "3" "等待 Jenkins 启动"
    sleep 15
    
    print_step "4" "获取初始管理员密码"
    local admin_password=$(docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword 2>/dev/null || echo "密码获取失败，请稍后查看")
    
    print_success "Jenkins 部署完成"
    print_info "访问地址：http://localhost:8082"
    print_info "初始管理员密码：$admin_password"
}

# 部署监控栈 (Prometheus + Grafana)
deploy_monitoring() {
    print_header "部署监控栈 (Prometheus + Grafana)"
    
    local monitoring_dir="$DEPLOY_DIR/monitoring"
    mkdir -p "$monitoring_dir"
    cd "$monitoring_dir"
    
    print_step "2" "创建 Prometheus 配置"
    cat > prometheus.yml << 'EOF'
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']
  
  - job_name: 'node-exporter'
    static_configs:
      - targets: ['node-exporter:9100']
EOF

    print_step "3" "创建 docker-compose.yml"
    cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  prometheus:
    image: prom/prometheus:latest
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml
      - prometheus_data:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--web.console.libraries=/etc/prometheus/console_libraries'
      - '--web.console.templates=/etc/prometheus/consoles'
    restart: unless-stopped

  grafana:
    image: grafana/grafana:latest
    ports:
      - "3000:3000"
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin
    volumes:
      - grafana_data:/var/lib/grafana
    restart: unless-stopped

  node-exporter:
    image: prom/node-exporter:latest
    ports:
      - "9100:9100"
    restart: unless-stopped

volumes:
  prometheus_data:
  grafana_data:
EOF

    print_step "4" "启动监控服务"
    if command -v docker-compose &> /dev/null; then
        docker-compose up -d
        print_success "监控栈部署完成"
        print_info "Prometheus: http://localhost:9090"
        print_info "Grafana: http://localhost:3000 (admin/admin)"
        print_info "Node Exporter: http://localhost:9100"
    else
        print_error "docker-compose 未安装，无法部署监控栈"
    fi
}

# 查看部署状态
view_deployments() {
    print_header "查看部署状态"
    
    echo -e "${CYAN}运行中的容器：${NC}"
    docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}"
    
    echo -e "\n${CYAN}数据卷：${NC}"
    docker volume ls
    
    echo -e "\n${CYAN}网络：${NC}"
    docker network ls
    
    echo -e "\n${CYAN}系统资源使用：${NC}"
    docker system df
}

# 停止所有部署的服务
stop_all_services() {
    print_header "停止所有部署的服务"
    
    local services=("nginx-server" "mysql-server" "redis-server" "portainer" "jenkins")
    
    for service in "${services[@]}"; do
        if docker ps -q -f name="$service" | grep -q .; then
            print_step "停止" "$service"
            docker stop "$service"
            print_success "$service 已停止"
        fi
    done
    
    # 停止 docker-compose 服务
    for dir in "$DEPLOY_DIR"/{wordpress,monitoring}; do
        if [ -f "$dir/docker-compose.yml" ]; then
            cd "$dir"
            if command -v docker-compose &> /dev/null; then
                docker-compose down
            fi
        fi
    done
    
    print_success "所有服务已停止"
}

# 清理所有部署
cleanup_deployments() {
    print_header "清理所有部署"
    
    read -p "确定要删除所有部署的服务和数据吗？(y/N): " confirm
    if [[ $confirm =~ ^[Yy]$ ]]; then
        stop_all_services
        
        print_step "删除" "容器"
        docker rm -f $(docker ps -aq --filter "name=nginx-server" --filter "name=mysql-server" --filter "name=redis-server" --filter "name=portainer" --filter "name=jenkins") 2>/dev/null || true
        
        print_step "删除" "数据卷"
        docker volume rm mysql-data redis-data portainer_data jenkins_data wordpress_data db_data prometheus_data grafana_data 2>/dev/null || true
        
        print_step "删除" "部署文件"
        rm -rf "$DEPLOY_DIR"
        
        print_success "清理完成"
    else
        print_info "取消清理操作"
    fi
}

# 显示主菜单
show_main_menu() {
    echo -e "\n${BLUE}=== Docker 自动化部署工具 ===${NC}"
    echo "1. 部署 Nginx Web 服务器"
    echo "2. 部署 MySQL 数据库"
    echo "3. 部署 Redis 缓存"
    echo "4. 部署 WordPress 博客"
    echo "5. 部署 Portainer 管理界面"
    echo "6. 部署 Jenkins CI/CD"
    echo "7. 部署监控栈 (Prometheus + Grafana)"
    echo "8. 查看部署状态"
    echo "9. 停止所有服务"
    echo "10. 清理所有部署"
    echo "11. 查看部署日志"
    echo "0. 退出"
    echo -e "${BLUE}================================${NC}\n"
}

# 查看部署日志
view_logs() {
    if [ -f "$LOG_FILE" ]; then
        print_header "部署日志"
        tail -50 "$LOG_FILE"
    else
        print_info "暂无部署日志"
    fi
}

# 主函数
main() {
    echo -e "${GREEN}欢迎使用 Docker 自动化部署工具！${NC}"
    
    # 检查依赖
    check_dependencies
    
    # 设置部署目录
    setup_deploy_directory
    
    while true; do
        show_main_menu
        read -p "请选择部署选项 (0-11): " choice
        
        case $choice in
            1) deploy_nginx ;;
            2) deploy_mysql ;;
            3) deploy_redis ;;
            4) deploy_wordpress ;;
            5) deploy_portainer ;;
            6) deploy_jenkins ;;
            7) deploy_monitoring ;;
            8) view_deployments ;;
            9) stop_all_services ;;
            10) cleanup_deployments ;;
            11) view_logs ;;
            0) 
                echo -e "${GREEN}感谢使用！${NC}"
                exit 0
                ;;
            *) 
                echo -e "${RED}无效选择，请重新输入${NC}"
                ;;
        esac
        
        echo
        read -p "按回车键继续..."
    done
}

# 运行主函数
main "$@"