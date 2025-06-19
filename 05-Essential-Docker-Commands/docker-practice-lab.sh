#!/bin/bash

# Docker 实践练习实验室
# 作者：Grissom
# 用途：提供实际的 Docker 练习环境和场景

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
LAB_DIR="$HOME/docker-practice-lab"
LOG_FILE="$LAB_DIR/practice.log"

# 工具函数
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
    echo -e "$1"
}

print_header() {
    echo -e "\n${PURPLE}=== $1 ===${NC}"
    log_message "开始练习：$1"
}

print_step() {
    echo -e "${CYAN}步骤 $1：${NC}$2"
}

print_command() {
    echo -e "${YELLOW}执行命令：${NC}$1"
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

# 检查Docker是否安装
check_docker() {
    if ! command -v docker &> /dev/null; then
        print_error "Docker 未安装，请先安装 Docker"
        exit 1
    fi
    
    if ! docker info &> /dev/null; then
        print_error "Docker 服务未运行，请启动 Docker"
        exit 1
    fi
    
    print_success "Docker 环境检查通过"
}

# 初始化实验环境
init_lab_environment() {
    print_header "初始化实验环境"
    
    # 创建实验目录
    mkdir -p "$LAB_DIR"/{web,database,logs,configs}
    
    # 创建示例文件
    cat > "$LAB_DIR/web/index.html" << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Docker 练习实验室</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; }
        .container { max-width: 800px; margin: 0 auto; }
        .header { background: #2196F3; color: white; padding: 20px; border-radius: 5px; }
        .content { padding: 20px; border: 1px solid #ddd; border-radius: 5px; margin-top: 20px; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🐳 Docker 练习实验室</h1>
            <p>欢迎来到 Docker 实践环境！</p>
        </div>
        <div class="content">
            <h2>当前时间</h2>
            <p id="time"></p>
            <h2>容器信息</h2>
            <p>这个页面运行在 Docker 容器中</p>
        </div>
    </div>
    <script>
        setInterval(() => {
            document.getElementById('time').textContent = new Date().toLocaleString();
        }, 1000);
    </script>
</body>
</html>
EOF

    # 创建 Dockerfile
    cat > "$LAB_DIR/web/Dockerfile" << 'EOF'
FROM nginx:alpine
COPY index.html /usr/share/nginx/html/
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
EOF

    # 创建 docker-compose.yml
    cat > "$LAB_DIR/docker-compose.yml" << 'EOF'
version: '3.8'
services:
  web:
    build: ./web
    ports:
      - "8080:80"
    volumes:
      - ./logs:/var/log/nginx
    networks:
      - lab-network
  
  database:
    image: mysql:8.0
    environment:
      MYSQL_ROOT_PASSWORD: rootpass
      MYSQL_DATABASE: testdb
      MYSQL_USER: testuser
      MYSQL_PASSWORD: testpass
    volumes:
      - db-data:/var/lib/mysql
      - ./database:/docker-entrypoint-initdb.d
    networks:
      - lab-network
  
  redis:
    image: redis:alpine
    networks:
      - lab-network

volumes:
  db-data:

networks:
  lab-network:
    driver: bridge
EOF

    # 创建数据库初始化脚本
    cat > "$LAB_DIR/database/init.sql" << 'EOF'
CREATE TABLE IF NOT EXISTS users (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    email VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO users (name, email) VALUES 
('张三', 'zhangsan@example.com'),
('李四', 'lisi@example.com'),
('王五', 'wangwu@example.com');
EOF

    print_success "实验环境初始化完成"
    print_info "实验目录：$LAB_DIR"
}

# 练习1：基础容器操作
practice_basic_containers() {
    print_header "练习1：基础容器操作"
    
    print_step "1" "拉取 Alpine Linux 镜像"
    print_command "docker pull alpine:latest"
    docker pull alpine:latest
    print_success "Alpine 镜像拉取完成"
    
    print_step "2" "运行交互式容器"
    print_command "docker run -it --name alpine-test alpine /bin/sh"
    print_info "容器将启动，你可以在其中执行命令，输入 'exit' 退出"
    docker run -it --name alpine-test alpine /bin/sh || true
    
    print_step "3" "查看容器状态"
    print_command "docker ps -a"
    docker ps -a
    
    print_step "4" "重新启动容器"
    print_command "docker start alpine-test"
    docker start alpine-test
    
    print_step "5" "在运行中的容器执行命令"
    print_command "docker exec alpine-test echo 'Hello from container!'"
    docker exec alpine-test echo 'Hello from container!'
    
    print_step "6" "停止并删除容器"
    print_command "docker stop alpine-test && docker rm alpine-test"
    docker stop alpine-test && docker rm alpine-test
    
    print_success "基础容器操作练习完成"
}

# 练习2：Web服务部署
practice_web_deployment() {
    print_header "练习2：Web服务部署"
    
    cd "$LAB_DIR"
    
    print_step "1" "构建自定义Web镜像"
    print_command "docker build -t lab-web ./web"
    docker build -t lab-web ./web
    print_success "Web镜像构建完成"
    
    print_step "2" "运行Web容器"
    print_command "docker run -d --name web-server -p 8080:80 lab-web"
    docker run -d --name web-server -p 8080:80 lab-web
    print_success "Web服务已启动"
    
    print_step "3" "测试Web服务"
    sleep 2
    if curl -s http://localhost:8080 > /dev/null; then
        print_success "Web服务访问正常"
        print_info "访问地址：http://localhost:8080"
    else
        print_error "Web服务访问失败"
    fi
    
    print_step "4" "查看容器日志"
    print_command "docker logs web-server"
    docker logs web-server
    
    print_step "5" "查看容器资源使用"
    print_command "docker stats --no-stream web-server"
    docker stats --no-stream web-server
    
    print_info "Web服务练习完成，容器将继续运行"
}

# 练习3：数据卷管理
practice_volume_management() {
    print_header "练习3：数据卷管理"
    
    print_step "1" "创建命名数据卷"
    print_command "docker volume create lab-data"
    docker volume create lab-data
    
    print_step "2" "查看数据卷信息"
    print_command "docker volume inspect lab-data"
    docker volume inspect lab-data
    
    print_step "3" "使用数据卷运行容器"
    print_command "docker run -d --name data-container -v lab-data:/data alpine tail -f /dev/null"
    docker run -d --name data-container -v lab-data:/data alpine tail -f /dev/null
    
    print_step "4" "在数据卷中创建文件"
    print_command "docker exec data-container sh -c 'echo \"Hello Volume\" > /data/test.txt'"
    docker exec data-container sh -c 'echo "Hello Volume" > /data/test.txt'
    
    print_step "5" "验证数据持久性"
    print_command "docker exec data-container cat /data/test.txt"
    docker exec data-container cat /data/test.txt
    
    print_step "6" "删除容器但保留数据卷"
    print_command "docker rm -f data-container"
    docker rm -f data-container
    
    print_step "7" "用新容器访问相同数据卷"
    print_command "docker run --rm -v lab-data:/data alpine cat /data/test.txt"
    docker run --rm -v lab-data:/data alpine cat /data/test.txt
    
    print_success "数据卷管理练习完成"
}

# 练习4：网络管理
practice_network_management() {
    print_header "练习4：网络管理"
    
    print_step "1" "创建自定义网络"
    print_command "docker network create lab-network"
    docker network create lab-network || true
    
    print_step "2" "查看网络信息"
    print_command "docker network ls"
    docker network ls
    
    print_step "3" "在自定义网络中运行容器"
    print_command "docker run -d --name server1 --network lab-network alpine tail -f /dev/null"
    docker run -d --name server1 --network lab-network alpine tail -f /dev/null
    
    print_command "docker run -d --name server2 --network lab-network alpine tail -f /dev/null"
    docker run -d --name server2 --network lab-network alpine tail -f /dev/null
    
    print_step "4" "测试容器间通信"
    print_command "docker exec server1 ping -c 3 server2"
    docker exec server1 ping -c 3 server2
    
    print_step "5" "查看网络详细信息"
    print_command "docker network inspect lab-network"
    docker network inspect lab-network
    
    print_step "6" "清理网络资源"
    print_command "docker rm -f server1 server2"
    docker rm -f server1 server2
    
    print_success "网络管理练习完成"
}

# 练习5：Docker Compose
practice_docker_compose() {
    print_header "练习5：Docker Compose 多服务部署"
    
    cd "$LAB_DIR"
    
    if ! command -v docker-compose &> /dev/null; then
        print_error "docker-compose 未安装，跳过此练习"
        return
    fi
    
    print_step "1" "启动多服务应用"
    print_command "docker-compose up -d"
    docker-compose up -d
    
    print_step "2" "查看服务状态"
    print_command "docker-compose ps"
    docker-compose ps
    
    print_step "3" "查看服务日志"
    print_command "docker-compose logs web"
    docker-compose logs web
    
    print_step "4" "测试数据库连接"
    sleep 10  # 等待数据库启动
    print_command "docker-compose exec database mysql -u testuser -ptestpass -e 'SELECT * FROM testdb.users;'"
    docker-compose exec database mysql -u testuser -ptestpass -e 'SELECT * FROM testdb.users;' || true
    
    print_step "5" "扩展Web服务"
    print_command "docker-compose up -d --scale web=3"
    docker-compose up -d --scale web=3
    
    print_info "多服务应用已启动，Web服务地址：http://localhost:8080"
    print_success "Docker Compose 练习完成"
}

# 练习6：镜像优化
practice_image_optimization() {
    print_header "练习6：镜像优化实践"
    
    cd "$LAB_DIR"
    
    print_step "1" "创建未优化的Dockerfile"
    cat > "Dockerfile.unoptimized" << 'EOF'
FROM ubuntu:20.04
RUN apt-get update
RUN apt-get install -y python3
RUN apt-get install -y python3-pip
RUN apt-get install -y curl
COPY . /app
WORKDIR /app
RUN pip3 install flask
EXPOSE 5000
CMD ["python3", "app.py"]
EOF

    print_step "2" "创建优化后的Dockerfile"
    cat > "Dockerfile.optimized" << 'EOF'
FROM python:3.9-alpine
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
EXPOSE 5000
CMD ["python", "app.py"]
EOF

    # 创建示例应用
    cat > "app.py" << 'EOF'
from flask import Flask
app = Flask(__name__)

@app.route('/')
def hello():
    return '<h1>Hello from Optimized Container!</h1>'

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
EOF

    cat > "requirements.txt" << 'EOF'
Flask==2.0.1
EOF

    print_step "3" "构建未优化镜像"
    print_command "docker build -f Dockerfile.unoptimized -t app:unoptimized ."
    docker build -f Dockerfile.unoptimized -t app:unoptimized . || true
    
    print_step "4" "构建优化镜像"
    print_command "docker build -f Dockerfile.optimized -t app:optimized ."
    docker build -f Dockerfile.optimized -t app:optimized .
    
    print_step "5" "比较镜像大小"
    print_command "docker images | grep app"
    docker images | grep app
    
    print_step "6" "运行优化后的应用"
    print_command "docker run -d --name optimized-app -p 5000:5000 app:optimized"
    docker run -d --name optimized-app -p 5000:5000 app:optimized
    
    sleep 2
    if curl -s http://localhost:5000 > /dev/null; then
        print_success "优化后的应用运行正常"
        print_info "访问地址：http://localhost:5000"
    fi
    
    print_success "镜像优化练习完成"
}

# 清理实验环境
cleanup_lab() {
    print_header "清理实验环境"
    
    cd "$LAB_DIR"
    
    print_step "1" "停止所有练习容器"
    docker stop $(docker ps -q --filter "name=alpine-test") 2>/dev/null || true
    docker stop $(docker ps -q --filter "name=web-server") 2>/dev/null || true
    docker stop $(docker ps -q --filter "name=data-container") 2>/dev/null || true
    docker stop $(docker ps -q --filter "name=server") 2>/dev/null || true
    docker stop $(docker ps -q --filter "name=optimized-app") 2>/dev/null || true
    
    print_step "2" "停止 Docker Compose 服务"
    docker-compose down -v 2>/dev/null || true
    
    print_step "3" "删除练习容器"
    docker rm $(docker ps -aq --filter "name=alpine-test") 2>/dev/null || true
    docker rm $(docker ps -aq --filter "name=web-server") 2>/dev/null || true
    docker rm $(docker ps -aq --filter "name=data-container") 2>/dev/null || true
    docker rm $(docker ps -aq --filter "name=server") 2>/dev/null || true
    docker rm $(docker ps -aq --filter "name=optimized-app") 2>/dev/null || true
    
    print_step "4" "删除练习镜像"
    docker rmi lab-web 2>/dev/null || true
    docker rmi app:unoptimized 2>/dev/null || true
    docker rmi app:optimized 2>/dev/null || true
    
    print_step "5" "删除数据卷"
    docker volume rm lab-data 2>/dev/null || true
    
    print_step "6" "删除网络"
    docker network rm lab-network 2>/dev/null || true
    
    print_success "实验环境清理完成"
}

# 显示练习菜单
show_practice_menu() {
    echo -e "\n${BLUE}=== Docker 实践练习实验室 ===${NC}"
    echo "1. 初始化实验环境"
    echo "2. 练习1：基础容器操作"
    echo "3. 练习2：Web服务部署"
    echo "4. 练习3：数据卷管理"
    echo "5. 练习4：网络管理"
    echo "6. 练习5：Docker Compose"
    echo "7. 练习6：镜像优化"
    echo "8. 查看练习日志"
    echo "9. 清理实验环境"
    echo "0. 退出"
    echo -e "${BLUE}================================${NC}\n"
}

# 查看练习日志
view_practice_log() {
    if [ -f "$LOG_FILE" ]; then
        print_header "练习日志"
        cat "$LOG_FILE"
    else
        print_info "暂无练习日志"
    fi
}

# 主函数
main() {
    echo -e "${GREEN}欢迎使用 Docker 实践练习实验室！${NC}"
    
    # 检查Docker环境
    check_docker
    
    # 创建日志目录
    mkdir -p "$(dirname "$LOG_FILE")"
    
    while true; do
        show_practice_menu
        read -p "请选择练习项目 (0-9): " choice
        
        case $choice in
            1) init_lab_environment ;;
            2) practice_basic_containers ;;
            3) practice_web_deployment ;;
            4) practice_volume_management ;;
            5) practice_network_management ;;
            6) practice_docker_compose ;;
            7) practice_image_optimization ;;
            8) view_practice_log ;;
            9) cleanup_lab ;;
            0) 
                echo -e "${GREEN}感谢使用 Docker 实践练习实验室！${NC}"
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