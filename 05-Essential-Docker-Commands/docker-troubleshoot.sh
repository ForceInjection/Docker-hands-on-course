#!/bin/bash

# Docker 故障排除和诊断工具
# 作者：Grissom
# 用途：帮助诊断和解决常见的 Docker 问题

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
REPORT_FILE="docker-diagnostic-report-$(date +%Y%m%d-%H%M%S).txt"

# 工具函数
print_header() {
    echo -e "\n${PURPLE}=== $1 ===${NC}"
    echo "=== $1 ===" >> "$REPORT_FILE"
}

print_subheader() {
    echo -e "\n${CYAN}--- $1 ---${NC}"
    echo "--- $1 ---" >> "$REPORT_FILE"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
    echo "✓ $1" >> "$REPORT_FILE"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
    echo "⚠ $1" >> "$REPORT_FILE"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
    echo "✗ $1" >> "$REPORT_FILE"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
    echo "ℹ $1" >> "$REPORT_FILE"
}

run_command() {
    local cmd="$1"
    local description="$2"
    
    echo -e "${YELLOW}执行：${NC}$cmd"
    echo "执行：$cmd" >> "$REPORT_FILE"
    
    if eval "$cmd" >> "$REPORT_FILE" 2>&1; then
        print_success "$description"
    else
        print_error "$description 失败"
    fi
    echo "" >> "$REPORT_FILE"
}

# 系统环境检查
check_system_environment() {
    print_header "系统环境检查"
    
    # 操作系统信息
    print_subheader "操作系统信息"
    run_command "uname -a" "获取系统信息"
    
    if [[ "$OSTYPE" == "darwin"* ]]; then
        run_command "sw_vers" "获取 macOS 版本信息"
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        run_command "cat /etc/os-release" "获取 Linux 发行版信息"
    fi
    
    # 系统资源
    print_subheader "系统资源"
    run_command "df -h" "磁盘使用情况"
    run_command "free -h" "内存使用情况" || run_command "vm_stat" "内存使用情况 (macOS)"
    run_command "uptime" "系统负载"
}

# Docker 安装检查
check_docker_installation() {
    print_header "Docker 安装检查"
    
    # Docker 版本
    if command -v docker &> /dev/null; then
        print_success "Docker 已安装"
        run_command "docker --version" "Docker 版本信息"
        run_command "docker version" "详细版本信息"
    else
        print_error "Docker 未安装"
        echo "请访问 https://docs.docker.com/get-docker/ 安装 Docker" >> "$REPORT_FILE"
        return 1
    fi
    
    # Docker Compose 检查
    if command -v docker-compose &> /dev/null; then
        print_success "Docker Compose 已安装"
        run_command "docker-compose --version" "Docker Compose 版本"
    else
        print_warning "Docker Compose 未安装"
    fi
}

# Docker 服务状态检查
check_docker_service() {
    print_header "Docker 服务状态检查"
    
    # Docker 守护进程状态
    if docker info &> /dev/null; then
        print_success "Docker 守护进程运行正常"
        run_command "docker info" "Docker 系统信息"
    else
        print_error "Docker 守护进程未运行或无法连接"
        
        # 尝试诊断问题
        print_subheader "诊断建议"
        if [[ "$OSTYPE" == "darwin"* ]]; then
            print_info "macOS 用户请检查："
            echo "1. Docker Desktop 是否已启动" >> "$REPORT_FILE"
            echo "2. 检查系统托盘中的 Docker 图标" >> "$REPORT_FILE"
            echo "3. 尝试重启 Docker Desktop" >> "$REPORT_FILE"
        elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
            print_info "Linux 用户请检查："
            echo "1. sudo systemctl status docker" >> "$REPORT_FILE"
            echo "2. sudo systemctl start docker" >> "$REPORT_FILE"
            echo "3. 检查用户是否在 docker 组中" >> "$REPORT_FILE"
        fi
        return 1
    fi
}

# 容器状态诊断
diagnose_containers() {
    print_header "容器状态诊断"
    
    # 运行中的容器
    print_subheader "运行中的容器"
    local running_containers=$(docker ps -q)
    if [ -n "$running_containers" ]; then
        run_command "docker ps" "运行中的容器列表"
        
        # 检查每个容器的资源使用
        print_subheader "容器资源使用"
        run_command "docker stats --no-stream" "容器资源统计"
    else
        print_info "当前没有运行中的容器"
    fi
    
    # 所有容器
    print_subheader "所有容器"
    run_command "docker ps -a" "所有容器列表"
    
    # 检查退出状态异常的容器
    print_subheader "异常退出的容器"
    local failed_containers=$(docker ps -a --filter "status=exited" --filter "exited=1" -q)
    if [ -n "$failed_containers" ]; then
        print_warning "发现异常退出的容器"
        for container in $failed_containers; do
            echo "容器 $container 的日志：" >> "$REPORT_FILE"
            docker logs --tail 50 "$container" >> "$REPORT_FILE" 2>&1
            echo "" >> "$REPORT_FILE"
        done
    else
        print_success "没有发现异常退出的容器"
    fi
}

# 镜像诊断
diagnose_images() {
    print_header "镜像诊断"
    
    # 镜像列表
    run_command "docker images" "本地镜像列表"
    
    # 悬空镜像
    print_subheader "悬空镜像检查"
    local dangling_images=$(docker images -f "dangling=true" -q)
    if [ -n "$dangling_images" ]; then
        print_warning "发现悬空镜像"
        run_command "docker images -f 'dangling=true'" "悬空镜像列表"
        print_info "建议运行：docker image prune"
    else
        print_success "没有悬空镜像"
    fi
    
    # 镜像大小分析
    print_subheader "镜像大小分析"
    run_command "docker images --format 'table {{.Repository}}\\t{{.Tag}}\\t{{.Size}}' | sort -k3 -hr" "按大小排序的镜像"
}

# 网络诊断
diagnose_networks() {
    print_header "网络诊断"
    
    # 网络列表
    run_command "docker network ls" "Docker 网络列表"
    
    # 检查默认网络
    print_subheader "默认网络检查"
    run_command "docker network inspect bridge" "bridge 网络详情"
    
    # 检查自定义网络
    local custom_networks=$(docker network ls --filter "type=custom" -q)
    if [ -n "$custom_networks" ]; then
        print_subheader "自定义网络"
        for network in $custom_networks; do
            run_command "docker network inspect $network" "网络 $network 详情"
        done
    fi
    
    # 网络连接测试
    print_subheader "网络连接测试"
    if docker ps -q > /dev/null; then
        local test_container=$(docker ps -q | head -1)
        if [ -n "$test_container" ]; then
            run_command "docker exec $test_container ping -c 3 8.8.8.8" "外网连接测试"
        fi
    fi
}

# 存储诊断
diagnose_storage() {
    print_header "存储诊断"
    
    # 数据卷
    print_subheader "数据卷检查"
    run_command "docker volume ls" "数据卷列表"
    
    # 未使用的数据卷
    local unused_volumes=$(docker volume ls -f "dangling=true" -q)
    if [ -n "$unused_volumes" ]; then
        print_warning "发现未使用的数据卷"
        run_command "docker volume ls -f 'dangling=true'" "未使用的数据卷"
        print_info "建议运行：docker volume prune"
    else
        print_success "没有未使用的数据卷"
    fi
    
    # 磁盘使用情况
    print_subheader "Docker 磁盘使用"
    run_command "docker system df" "Docker 磁盘使用统计"
    run_command "docker system df -v" "详细磁盘使用信息"
}

# 性能诊断
diagnose_performance() {
    print_header "性能诊断"
    
    # Docker 守护进程资源使用
    print_subheader "Docker 守护进程"
    if command -v ps &> /dev/null; then
        run_command "ps aux | grep docker" "Docker 进程信息"
    fi
    
    # 容器性能统计
    if docker ps -q > /dev/null; then
        print_subheader "容器性能统计"
        run_command "docker stats --no-stream --format 'table {{.Container}}\\t{{.CPUPerc}}\\t{{.MemUsage}}\\t{{.NetIO}}\\t{{.BlockIO}}'" "容器性能概览"
    fi
    
    # 系统事件
    print_subheader "最近的 Docker 事件"
    run_command "docker events --since '1h' --until '0s'" "最近1小时的事件" || print_info "无最近事件"
}

# 常见问题检查
check_common_issues() {
    print_header "常见问题检查"
    
    # 检查端口冲突
    print_subheader "端口冲突检查"
    local common_ports=("80" "443" "3000" "8080" "8000" "5000")
    for port in "${common_ports[@]}"; do
        if lsof -i :"$port" &> /dev/null || netstat -an | grep ":$port " &> /dev/null; then
            print_warning "端口 $port 正在被使用"
            if command -v lsof &> /dev/null; then
                lsof -i :"$port" >> "$REPORT_FILE" 2>&1 || true
            fi
        fi
    done
    
    # 检查磁盘空间
    print_subheader "磁盘空间检查"
    local disk_usage=$(df / | awk 'NR==2 {print $5}' | sed 's/%//')
    if [ "$disk_usage" -gt 90 ]; then
        print_error "磁盘使用率过高：${disk_usage}%"
        print_info "建议清理 Docker 资源：docker system prune -a"
    elif [ "$disk_usage" -gt 80 ]; then
        print_warning "磁盘使用率较高：${disk_usage}%"
    else
        print_success "磁盘空间充足：${disk_usage}%"
    fi
    
    # 检查内存使用
    print_subheader "内存使用检查"
    if command -v free &> /dev/null; then
        local mem_usage=$(free | awk 'NR==2{printf "%.0f", $3*100/$2}')
        if [ "$mem_usage" -gt 90 ]; then
            print_error "内存使用率过高：${mem_usage}%"
        elif [ "$mem_usage" -gt 80 ]; then
            print_warning "内存使用率较高：${mem_usage}%"
        else
            print_success "内存使用正常：${mem_usage}%"
        fi
    fi
}

# 生成修复建议
generate_recommendations() {
    print_header "修复建议"
    
    echo "基于诊断结果，以下是一些建议：" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
    
    # 清理建议
    echo "1. 定期清理 Docker 资源：" >> "$REPORT_FILE"
    echo "   docker system prune -a --volumes  # 清理所有未使用的资源" >> "$REPORT_FILE"
    echo "   docker image prune                # 清理悬空镜像" >> "$REPORT_FILE"
    echo "   docker volume prune               # 清理未使用的数据卷" >> "$REPORT_FILE"
    echo "   docker network prune              # 清理未使用的网络" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
    
    # 监控建议
    echo "2. 监控建议：" >> "$REPORT_FILE"
    echo "   docker stats                      # 实时监控容器资源" >> "$REPORT_FILE"
    echo "   docker system df                  # 检查磁盘使用" >> "$REPORT_FILE"
    echo "   docker system events              # 监控系统事件" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
    
    # 性能优化建议
    echo "3. 性能优化：" >> "$REPORT_FILE"
    echo "   - 使用多阶段构建减小镜像大小" >> "$REPORT_FILE"
    echo "   - 合理设置容器资源限制" >> "$REPORT_FILE"
    echo "   - 使用 .dockerignore 文件" >> "$REPORT_FILE"
    echo "   - 定期更新基础镜像" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
    
    # 安全建议
    echo "4. 安全建议：" >> "$REPORT_FILE"
    echo "   - 不要以 root 用户运行容器" >> "$REPORT_FILE"
    echo "   - 使用官方镜像或可信源" >> "$REPORT_FILE"
    echo "   - 定期扫描镜像漏洞" >> "$REPORT_FILE"
    echo "   - 限制容器网络访问" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
    
    print_info "详细建议已写入报告文件"
}

# 快速修复
quick_fix() {
    print_header "快速修复工具"
    
    echo "选择要执行的修复操作："
    echo "1. 清理悬空镜像"
    echo "2. 清理停止的容器"
    echo "3. 清理未使用的数据卷"
    echo "4. 清理未使用的网络"
    echo "5. 完整系统清理"
    echo "6. 重启 Docker 服务 (Linux)"
    echo "0. 返回主菜单"
    
    read -p "请选择 (0-6): " choice
    
    case $choice in
        1)
            print_info "清理悬空镜像..."
            docker image prune -f
            print_success "悬空镜像清理完成"
            ;;
        2)
            print_info "清理停止的容器..."
            docker container prune -f
            print_success "停止的容器清理完成"
            ;;
        3)
            print_info "清理未使用的数据卷..."
            docker volume prune -f
            print_success "未使用的数据卷清理完成"
            ;;
        4)
            print_info "清理未使用的网络..."
            docker network prune -f
            print_success "未使用的网络清理完成"
            ;;
        5)
            print_info "执行完整系统清理..."
            docker system prune -a --volumes -f
            print_success "系统清理完成"
            ;;
        6)
            if [[ "$OSTYPE" == "linux-gnu"* ]]; then
                print_info "重启 Docker 服务..."
                sudo systemctl restart docker
                print_success "Docker 服务重启完成"
            else
                print_warning "此功能仅适用于 Linux 系统"
            fi
            ;;
        0)
            return
            ;;
        *)
            print_error "无效选择"
            ;;
    esac
}

# 显示主菜单
show_main_menu() {
    echo -e "\n${BLUE}=== Docker 故障排除工具 ===${NC}"
    echo "1. 完整系统诊断"
    echo "2. 系统环境检查"
    echo "3. Docker 安装检查"
    echo "4. Docker 服务检查"
    echo "5. 容器诊断"
    echo "6. 镜像诊断"
    echo "7. 网络诊断"
    echo "8. 存储诊断"
    echo "9. 性能诊断"
    echo "10. 常见问题检查"
    echo "11. 快速修复"
    echo "12. 查看诊断报告"
    echo "0. 退出"
    echo -e "${BLUE}===============================${NC}\n"
}

# 完整诊断
full_diagnosis() {
    print_header "开始完整 Docker 系统诊断"
    echo "诊断开始时间：$(date)" > "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
    
    check_system_environment
    check_docker_installation
    check_docker_service
    diagnose_containers
    diagnose_images
    diagnose_networks
    diagnose_storage
    diagnose_performance
    check_common_issues
    generate_recommendations
    
    echo "诊断完成时间：$(date)" >> "$REPORT_FILE"
    print_success "完整诊断完成，报告已保存到：$REPORT_FILE"
}

# 查看诊断报告
view_report() {
    if [ -f "$REPORT_FILE" ]; then
        print_header "诊断报告"
        cat "$REPORT_FILE"
    else
        print_warning "未找到诊断报告，请先运行诊断"
    fi
}

# 主函数
main() {
    echo -e "${GREEN}欢迎使用 Docker 故障排除工具！${NC}"
    
    while true; do
        show_main_menu
        read -p "请选择功能 (0-12): " choice
        
        case $choice in
            1) full_diagnosis ;;
            2) check_system_environment ;;
            3) check_docker_installation ;;
            4) check_docker_service ;;
            5) diagnose_containers ;;
            6) diagnose_images ;;
            7) diagnose_networks ;;
            8) diagnose_storage ;;
            9) diagnose_performance ;;
            10) check_common_issues ;;
            11) quick_fix ;;
            12) view_report ;;
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