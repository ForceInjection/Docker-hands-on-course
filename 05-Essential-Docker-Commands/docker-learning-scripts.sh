#!/bin/bash

# Docker 学习练习脚本
# 作者：Grissom
# 用途：帮助用户通过实践学习 Docker 命令

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 打印带颜色的消息
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查 Docker 是否安装
check_docker() {
    if ! command -v docker &> /dev/null; then
        print_error "Docker 未安装，请先安装 Docker"
        exit 1
    fi
    
    if ! docker info &> /dev/null; then
        print_error "Docker 服务未启动，请启动 Docker 服务"
        exit 1
    fi
    
    print_success "Docker 环境检查通过"
}

# 显示菜单
show_menu() {
    echo -e "\n${BLUE}=== Docker 学习练习菜单 ===${NC}"
    echo "1. 基础容器操作练习"
    echo "2. 镜像管理练习"
    echo "3. 网络和存储练习"
    echo "4. 监控和调试练习"
    echo "5. 批量操作练习"
    echo "6. 清理环境"
    echo "7. 显示系统信息"
    echo "0. 退出"
    echo -e "${BLUE}=========================${NC}\n"
}

# 基础容器操作练习
practice_container_basics() {
    print_info "开始基础容器操作练习..."
    
    # 拉取测试镜像
    print_info "1. 拉取 nginx 镜像"
    docker pull nginx:alpine
    
    # 运行容器
    print_info "2. 运行 nginx 容器"
    docker run -d --name learning-nginx -p 8080:80 nginx:alpine
    
    # 查看运行中的容器
    print_info "3. 查看运行中的容器"
    docker ps
    
    # 查看容器日志
    print_info "4. 查看容器日志"
    docker logs learning-nginx
    
    # 进入容器
    print_info "5. 进入容器（按 Ctrl+D 退出）"
    echo "即将进入容器，你可以执行 'ls -la' 查看文件，'exit' 退出"
    read -p "按回车键继续..."
    docker exec -it learning-nginx /bin/sh
    
    # 停止容器
    print_info "6. 停止容器"
    docker stop learning-nginx
    
    # 删除容器
    print_info "7. 删除容器"
    docker rm learning-nginx
    
    print_success "基础容器操作练习完成！"
}

# 镜像管理练习
practice_image_management() {
    print_info "开始镜像管理练习..."
    
    # 查看本地镜像
    print_info "1. 查看本地镜像"
    docker images
    
    # 拉取不同版本的镜像
    print_info "2. 拉取不同版本的 alpine 镜像"
    docker pull alpine:3.15
    docker pull alpine:latest
    
    # 为镜像添加标签
    print_info "3. 为镜像添加自定义标签"
    docker tag alpine:latest my-alpine:v1.0
    
    # 查看镜像详细信息
    print_info "4. 查看镜像详细信息"
    docker inspect alpine:latest
    
    # 创建简单的 Dockerfile
    print_info "5. 创建并构建自定义镜像"
    cat > /tmp/Dockerfile << EOF
FROM alpine:latest
RUN echo "Hello Docker Learning!" > /hello.txt
CMD cat /hello.txt
EOF
    
    docker build -t learning-image:v1.0 -f /tmp/Dockerfile /tmp/
    
    # 运行自定义镜像
    print_info "6. 运行自定义镜像"
    docker run --rm learning-image:v1.0
    
    # 清理测试镜像
    print_info "7. 清理测试镜像"
    docker rmi learning-image:v1.0 my-alpine:v1.0
    rm -f /tmp/Dockerfile
    
    print_success "镜像管理练习完成！"
}

# 网络和存储练习
practice_network_storage() {
    print_info "开始网络和存储练习..."
    
    # 创建自定义网络
    print_info "1. 创建自定义网络"
    docker network create learning-network
    
    # 查看网络列表
    print_info "2. 查看网络列表"
    docker network ls
    
    # 创建数据卷
    print_info "3. 创建数据卷"
    docker volume create learning-volume
    
    # 查看数据卷列表
    print_info "4. 查看数据卷列表"
    docker volume ls
    
    # 运行容器并连接到自定义网络和数据卷
    print_info "5. 运行容器并使用自定义网络和数据卷"
    docker run -d --name network-test \
        --network learning-network \
        -v learning-volume:/data \
        alpine:latest sleep 300
    
    # 查看网络详细信息
    print_info "6. 查看网络详细信息"
    docker network inspect learning-network
    
    # 在容器中创建文件测试数据卷
    print_info "7. 测试数据卷持久化"
    docker exec network-test sh -c "echo 'Hello Volume!' > /data/test.txt"
    docker exec network-test cat /data/test.txt
    
    # 清理资源
    print_info "8. 清理网络和存储资源"
    docker stop network-test
    docker rm network-test
    docker network rm learning-network
    docker volume rm learning-volume
    
    print_success "网络和存储练习完成！"
}

# 监控和调试练习
practice_monitoring_debugging() {
    print_info "开始监控和调试练习..."
    
    # 运行一个会产生日志的容器
    print_info "1. 运行测试容器"
    docker run -d --name monitor-test alpine:latest sh -c 'while true; do echo "Current time: $(date)"; sleep 5; done'
    
    # 查看实时日志
    print_info "2. 查看实时日志（10秒后自动停止）"
    timeout 10 docker logs -f monitor-test || true
    
    # 查看容器进程
    print_info "3. 查看容器进程"
    docker top monitor-test
    
    # 查看容器资源使用情况
    print_info "4. 查看容器资源使用情况（5秒）"
    timeout 5 docker stats monitor-test --no-stream
    
    # 查看容器详细信息
    print_info "5. 查看容器详细配置信息"
    docker inspect monitor-test | head -20
    
    # 在容器中执行命令
    print_info "6. 在容器中执行调试命令"
    docker exec monitor-test ps aux
    docker exec monitor-test df -h
    
    # 清理测试容器
    print_info "7. 清理测试容器"
    docker stop monitor-test
    docker rm monitor-test
    
    print_success "监控和调试练习完成！"
}

# 批量操作练习
practice_batch_operations() {
    print_info "开始批量操作练习..."
    
    # 创建多个测试容器
    print_info "1. 创建多个测试容器"
    for i in {1..3}; do
        docker run -d --name batch-test-$i alpine:latest sleep 300
    done
    
    # 查看所有容器
    print_info "2. 查看所有容器"
    docker ps
    
    # 批量停止容器
    print_info "3. 批量停止测试容器"
    docker stop $(docker ps -q --filter "name=batch-test")
    
    # 批量删除容器
    print_info "4. 批量删除测试容器"
    docker rm $(docker ps -aq --filter "name=batch-test")
    
    # 显示批量操作命令示例
    print_info "5. 常用批量操作命令示例："
    echo "   停止所有运行中的容器: docker stop \$(docker ps -q)"
    echo "   删除所有停止的容器: docker rm \$(docker ps -aq)"
    echo "   删除所有悬空镜像: docker image prune"
    echo "   删除所有未使用的镜像: docker image prune -a"
    
    print_success "批量操作练习完成！"
}

# 清理环境
clean_environment() {
    print_warning "开始清理 Docker 环境..."
    
    # 停止所有运行中的容器
    print_info "1. 停止所有运行中的容器"
    if [ "$(docker ps -q)" ]; then
        docker stop $(docker ps -q)
    else
        echo "   没有运行中的容器"
    fi
    
    # 删除所有停止的容器
    print_info "2. 删除所有停止的容器"
    docker container prune -f
    
    # 删除悬空镜像
    print_info "3. 删除悬空镜像"
    docker image prune -f
    
    # 删除未使用的网络
    print_info "4. 删除未使用的网络"
    docker network prune -f
    
    # 删除未使用的数据卷
    print_info "5. 删除未使用的数据卷"
    docker volume prune -f
    
    print_success "环境清理完成！"
}

# 显示系统信息
show_system_info() {
    print_info "Docker 系统信息："
    echo -e "\n${YELLOW}=== Docker 版本信息 ===${NC}"
    docker version
    
    echo -e "\n${YELLOW}=== Docker 系统信息 ===${NC}"
    docker info
    
    echo -e "\n${YELLOW}=== 磁盘使用情况 ===${NC}"
    docker system df
    
    echo -e "\n${YELLOW}=== 运行中的容器 ===${NC}"
    docker ps
    
    echo -e "\n${YELLOW}=== 本地镜像 ===${NC}"
    docker images
}

# 主函数
main() {
    echo -e "${GREEN}欢迎使用 Docker 学习练习脚本！${NC}"
    
    # 检查 Docker 环境
    check_docker
    
    while true; do
        show_menu
        read -p "请选择操作 (0-7): " choice
        
        case $choice in
            1)
                practice_container_basics
                ;;
            2)
                practice_image_management
                ;;
            3)
                practice_network_storage
                ;;
            4)
                practice_monitoring_debugging
                ;;
            5)
                practice_batch_operations
                ;;
            6)
                clean_environment
                ;;
            7)
                show_system_info
                ;;
            0)
                print_info "感谢使用 Docker 学习练习脚本！"
                exit 0
                ;;
            *)
                print_error "无效选择，请重新输入"
                ;;
        esac
        
        echo
        read -p "按回车键继续..."
    done
}

# 运行主函数
main "$@"