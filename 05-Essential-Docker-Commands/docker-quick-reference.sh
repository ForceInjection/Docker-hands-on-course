#!/bin/bash

# Docker 命令速查和测试脚本
# 作者：Grissom
# 用途：提供 Docker 命令快速参考和测试功能

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 打印函数
print_header() {
    echo -e "\n${PURPLE}=== $1 ===${NC}"
}

print_command() {
    echo -e "${CYAN}$1${NC}"
}

print_description() {
    echo -e "${YELLOW}描述：${NC}$1"
}

print_example() {
    echo -e "${GREEN}示例：${NC}$1"
}

# 显示主菜单
show_main_menu() {
    echo -e "\n${BLUE}=== Docker 命令速查工具 ===${NC}"
    echo "1. 容器管理命令"
    echo "2. 镜像管理命令"
    echo "3. 网络管理命令"
    echo "4. 存储管理命令"
    echo "5. 监控调试命令"
    echo "6. 系统管理命令"
    echo "7. 常用命令组合"
    echo "8. 命令测试模式"
    echo "9. 生成命令备忘单"
    echo "0. 退出"
    echo -e "${BLUE}=========================${NC}\n"
}

# 容器管理命令
show_container_commands() {
    print_header "容器管理命令"
    
    print_command "docker ps"
    print_description "列出运行中的容器"
    print_example "docker ps -a  # 显示所有容器（包括停止的）"
    echo
    
    print_command "docker run"
    print_description "创建并运行容器"
    print_example "docker run -d --name web -p 8080:80 nginx"
    echo
    
    print_command "docker start/stop/restart"
    print_description "启动/停止/重启容器"
    print_example "docker start container_name"
    echo
    
    print_command "docker exec"
    print_description "在运行中的容器内执行命令"
    print_example "docker exec -it container_name /bin/bash"
    echo
    
    print_command "docker logs"
    print_description "查看容器日志"
    print_example "docker logs -f container_name  # 实时跟踪日志"
    echo
    
    print_command "docker rm"
    print_description "删除容器"
    print_example "docker rm container_name  # 删除停止的容器"
    echo
    
    print_command "docker cp"
    print_description "在容器和主机间复制文件"
    print_example "docker cp file.txt container:/path/"
    echo
}

# 镜像管理命令
show_image_commands() {
    print_header "镜像管理命令"
    
    print_command "docker images"
    print_description "列出本地镜像"
    print_example "docker images -q  # 只显示镜像ID"
    echo
    
    print_command "docker pull"
    print_description "拉取镜像"
    print_example "docker pull nginx:latest"
    echo
    
    print_command "docker push"
    print_description "推送镜像到仓库"
    print_example "docker push username/image:tag"
    echo
    
    print_command "docker build"
    print_description "从Dockerfile构建镜像"
    print_example "docker build -t myapp:v1.0 ."
    echo
    
    print_command "docker tag"
    print_description "为镜像添加标签"
    print_example "docker tag image:old image:new"
    echo
    
    print_command "docker rmi"
    print_description "删除镜像"
    print_example "docker rmi image_name"
    echo
    
    print_command "docker save/load"
    print_description "保存/加载镜像"
    print_example "docker save image > image.tar"
    echo
}

# 网络管理命令
show_network_commands() {
    print_header "网络管理命令"
    
    print_command "docker network ls"
    print_description "列出所有网络"
    print_example "docker network ls"
    echo
    
    print_command "docker network create"
    print_description "创建自定义网络"
    print_example "docker network create --driver bridge mynet"
    echo
    
    print_command "docker network inspect"
    print_description "查看网络详细信息"
    print_example "docker network inspect bridge"
    echo
    
    print_command "docker network connect/disconnect"
    print_description "连接/断开容器网络"
    print_example "docker network connect mynet container"
    echo
    
    print_command "docker port"
    print_description "查看端口映射"
    print_example "docker port container_name"
    echo
}

# 存储管理命令
show_volume_commands() {
    print_header "存储管理命令"
    
    print_command "docker volume ls"
    print_description "列出所有数据卷"
    print_example "docker volume ls"
    echo
    
    print_command "docker volume create"
    print_description "创建数据卷"
    print_example "docker volume create myvolume"
    echo
    
    print_command "docker volume inspect"
    print_description "查看数据卷详细信息"
    print_example "docker volume inspect myvolume"
    echo
    
    print_command "docker volume rm"
    print_description "删除数据卷"
    print_example "docker volume rm myvolume"
    echo
    
    print_command "docker volume prune"
    print_description "删除未使用的数据卷"
    print_example "docker volume prune -f"
    echo
}

# 监控调试命令
show_monitoring_commands() {
    print_header "监控调试命令"
    
    print_command "docker stats"
    print_description "显示容器资源使用统计"
    print_example "docker stats --no-stream"
    echo
    
    print_command "docker top"
    print_description "显示容器中运行的进程"
    print_example "docker top container_name"
    echo
    
    print_command "docker inspect"
    print_description "查看容器/镜像详细信息"
    print_example "docker inspect container_name"
    echo
    
    print_command "docker diff"
    print_description "查看容器文件系统变化"
    print_example "docker diff container_name"
    echo
    
    print_command "docker events"
    print_description "实时显示Docker事件"
    print_example "docker events --since '2023-01-01'"
    echo
}

# 系统管理命令
show_system_commands() {
    print_header "系统管理命令"
    
    print_command "docker version"
    print_description "显示Docker版本信息"
    print_example "docker version"
    echo
    
    print_command "docker info"
    print_description "显示系统信息"
    print_example "docker info"
    echo
    
    print_command "docker system df"
    print_description "显示磁盘使用情况"
    print_example "docker system df -v"
    echo
    
    print_command "docker system prune"
    print_description "清理系统资源"
    print_example "docker system prune -a --volumes"
    echo
    
    print_command "docker login/logout"
    print_description "登录/注销Docker Hub"
    print_example "docker login -u username"
    echo
}

# 常用命令组合
show_command_combinations() {
    print_header "常用命令组合"
    
    echo -e "${YELLOW}1. 停止并删除所有容器${NC}"
    print_example "docker stop \$(docker ps -q) && docker rm \$(docker ps -aq)"
    echo
    
    echo -e "${YELLOW}2. 删除所有镜像${NC}"
    print_example "docker rmi \$(docker images -q)"
    echo
    
    echo -e "${YELLOW}3. 一键清理系统${NC}"
    print_example "docker system prune -a --volumes -f"
    echo
    
    echo -e "${YELLOW}4. 查看容器IP地址${NC}"
    print_example "docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' container"
    echo
    
    echo -e "${YELLOW}5. 批量删除悬空镜像${NC}"
    print_example "docker image prune -f"
    echo
    
    echo -e "${YELLOW}6. 运行临时容器（退出后自动删除）${NC}"
    print_example "docker run --rm -it alpine /bin/sh"
    echo
    
    echo -e "${YELLOW}7. 查看容器环境变量${NC}"
    print_example "docker exec container env"
    echo
    
    echo -e "${YELLOW}8. 实时监控所有容器资源${NC}"
    print_example "docker stats --format 'table {{.Container}}\\t{{.CPUPerc}}\\t{{.MemUsage}}'"
    echo
}

# 命令测试模式
command_test_mode() {
    print_header "命令测试模式"
    
    echo -e "${YELLOW}这个模式将帮助你测试 Docker 命令的理解程度${NC}\n"
    
    # 测试题目数组
    declare -a questions=(
        "如何查看所有容器（包括停止的）？|docker ps -a"
        "如何进入运行中的容器？|docker exec -it container_name /bin/bash"
        "如何查看容器实时日志？|docker logs -f container_name"
        "如何删除所有停止的容器？|docker container prune"
        "如何查看镜像构建历史？|docker history image_name"
        "如何创建自定义网络？|docker network create network_name"
        "如何查看容器资源使用情况？|docker stats"
        "如何强制删除镜像？|docker rmi -f image_name"
        "如何复制文件到容器？|docker cp file container:/path"
        "如何查看Docker系统信息？|docker info"
    )
    
    local score=0
    local total=${#questions[@]}
    
    for question_data in "${questions[@]}"; do
        IFS='|' read -r question answer <<< "$question_data"
        
        echo -e "${CYAN}问题：${NC}$question"
        read -p "你的答案：" user_answer
        
        if [[ "$user_answer" == "$answer" ]]; then
            echo -e "${GREEN}✓ 正确！${NC}\n"
            ((score++))
        else
            echo -e "${RED}✗ 错误。正确答案是：${NC}$answer\n"
        fi
    done
    
    echo -e "${PURPLE}测试完成！${NC}"
    echo -e "你的得分：${GREEN}$score${NC}/${total}"
    
    if [ $score -eq $total ]; then
        echo -e "${GREEN}🎉 完美！你已经掌握了这些命令！${NC}"
    elif [ $score -ge $((total * 3 / 4)) ]; then
        echo -e "${YELLOW}👍 很好！继续加油！${NC}"
    else
        echo -e "${RED}💪 需要更多练习，建议回顾相关命令。${NC}"
    fi
}

# 生成命令备忘单
generate_cheatsheet() {
    local cheatsheet_file="docker-cheatsheet.md"
    
    print_header "生成 Docker 命令备忘单"
    
    cat > "$cheatsheet_file" << 'EOF'
# Docker 命令备忘单

## 容器管理
```bash
# 查看容器
docker ps                    # 运行中的容器
docker ps -a                 # 所有容器

# 运行容器
docker run -d --name myapp nginx
docker run -it alpine /bin/sh

# 容器控制
docker start/stop/restart container
docker pause/unpause container

# 进入容器
docker exec -it container /bin/bash

# 查看日志
docker logs -f container

# 删除容器
docker rm container
docker rm -f container       # 强制删除
```

## 镜像管理
```bash
# 查看镜像
docker images
docker images -q             # 只显示ID

# 拉取/推送镜像
docker pull image:tag
docker push image:tag

# 构建镜像
docker build -t name:tag .

# 删除镜像
docker rmi image
docker image prune           # 删除悬空镜像
```

## 网络管理
```bash
# 网络操作
docker network ls
docker network create mynet
docker network inspect mynet
docker network connect mynet container
```

## 存储管理
```bash
# 数据卷操作
docker volume ls
docker volume create myvolume
docker volume inspect myvolume
docker volume rm myvolume
```

## 监控调试
```bash
# 监控
docker stats
docker top container
docker inspect container

# 系统信息
docker info
docker version
docker system df
```

## 批量操作
```bash
# 停止所有容器
docker stop $(docker ps -q)

# 删除所有停止的容器
docker container prune

# 删除所有镜像
docker rmi $(docker images -q)

# 系统清理
docker system prune -a
```

## 常用参数
- `-d`: 后台运行
- `-it`: 交互式终端
- `-p`: 端口映射
- `-v`: 数据卷挂载
- `--name`: 指定名称
- `--rm`: 退出后删除
- `-f`: 强制执行
EOF

    echo -e "${GREEN}备忘单已生成：$cheatsheet_file${NC}"
    echo -e "${YELLOW}你可以使用以下命令查看：${NC}"
    echo "cat $cheatsheet_file"
}

# 主函数
main() {
    echo -e "${GREEN}欢迎使用 Docker 命令速查工具！${NC}"
    
    while true; do
        show_main_menu
        read -p "请选择功能 (0-9): " choice
        
        case $choice in
            1) show_container_commands ;;
            2) show_image_commands ;;
            3) show_network_commands ;;
            4) show_volume_commands ;;
            5) show_monitoring_commands ;;
            6) show_system_commands ;;
            7) show_command_combinations ;;
            8) command_test_mode ;;
            9) generate_cheatsheet ;;
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