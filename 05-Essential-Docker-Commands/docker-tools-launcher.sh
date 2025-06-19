#!/bin/bash

# Docker 工具启动器
# 作者：Grissom
# 用途：统一管理和启动所有 Docker 学习工具

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 工具脚本列表
declare -A TOOLS=(
    ["1"]="docker-learning-scripts.sh|Docker 交互式学习脚本|提供分类的 Docker 命令学习和练习"
    ["2"]="docker-quick-reference.sh|Docker 命令速查工具|快速查找 Docker 命令和生成备忘单"
    ["3"]="docker-practice-lab.sh|Docker 实践练习实验室|提供实际的 Docker 练习环境和场景"
    ["4"]="docker-troubleshoot.sh|Docker 故障排除工具|诊断和解决常见的 Docker 问题"
    ["5"]="docker-auto-deploy.sh|Docker 自动化部署工具|一键部署常见应用和服务"
)

# 工具函数
print_header() {
    echo -e "\n${PURPLE}=== $1 ===${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

# 检查脚本文件是否存在
check_script_files() {
    local missing_files=()
    
    for key in "${!TOOLS[@]}"; do
        IFS='|' read -r script_name tool_name description <<< "${TOOLS[$key]}"
        local script_path="$SCRIPT_DIR/$script_name"
        
        if [ ! -f "$script_path" ]; then
            missing_files+=("$script_name")
        fi
    done
    
    if [ ${#missing_files[@]} -gt 0 ]; then
        print_error "以下脚本文件缺失："
        for file in "${missing_files[@]}"; do
            echo "  - $file"
        done
        return 1
    fi
    
    return 0
}

# 设置脚本执行权限
setup_permissions() {
    print_info "设置脚本执行权限..."
    
    for key in "${!TOOLS[@]}"; do
        IFS='|' read -r script_name tool_name description <<< "${TOOLS[$key]}"
        local script_path="$SCRIPT_DIR/$script_name"
        
        if [ -f "$script_path" ]; then
            chmod +x "$script_path"
            print_success "$script_name 权限设置完成"
        fi
    done
    
    # 设置启动器自身的权限
    chmod +x "$0"
}

# 显示工具信息
show_tool_info() {
    local tool_key="$1"
    
    if [[ -n "${TOOLS[$tool_key]}" ]]; then
        IFS='|' read -r script_name tool_name description <<< "${TOOLS[$tool_key]}"
        
        print_header "$tool_name"
        echo -e "${CYAN}脚本文件：${NC}$script_name"
        echo -e "${CYAN}功能描述：${NC}$description"
        echo -e "${CYAN}文件路径：${NC}$SCRIPT_DIR/$script_name"
        
        local script_path="$SCRIPT_DIR/$script_name"
        if [ -f "$script_path" ]; then
            local file_size=$(ls -lh "$script_path" | awk '{print $5}')
            local file_date=$(ls -l "$script_path" | awk '{print $6, $7, $8}')
            echo -e "${CYAN}文件大小：${NC}$file_size"
            echo -e "${CYAN}修改时间：${NC}$file_date"
            print_success "脚本文件存在且可执行"
        else
            print_error "脚本文件不存在"
        fi
    else
        print_error "无效的工具编号"
    fi
}

# 运行指定工具
run_tool() {
    local tool_key="$1"
    
    if [[ -n "${TOOLS[$tool_key]}" ]]; then
        IFS='|' read -r script_name tool_name description <<< "${TOOLS[$tool_key]}"
        local script_path="$SCRIPT_DIR/$script_name"
        
        if [ -f "$script_path" ] && [ -x "$script_path" ]; then
            print_info "启动 $tool_name..."
            echo -e "${YELLOW}按 Ctrl+C 返回主菜单${NC}\n"
            
            # 运行脚本
            "$script_path"
        else
            print_error "脚本文件不存在或没有执行权限：$script_path"
            print_info "尝试重新设置权限..."
            setup_permissions
        fi
    else
        print_error "无效的工具编号"
    fi
}

# 显示所有工具的状态
show_tools_status() {
    print_header "Docker 工具状态检查"
    
    echo -e "${CYAN}工具目录：${NC}$SCRIPT_DIR"
    echo -e "${CYAN}检查时间：${NC}$(date)\n"
    
    printf "%-5s %-35s %-10s %-15s\n" "编号" "工具名称" "状态" "文件大小"
    printf "%-5s %-35s %-10s %-15s\n" "----" "------------------------------------" "--------" "-------------"
    
    for key in $(printf '%s\n' "${!TOOLS[@]}" | sort -n); do
        IFS='|' read -r script_name tool_name description <<< "${TOOLS[$key]}"
        local script_path="$SCRIPT_DIR/$script_name"
        
        if [ -f "$script_path" ]; then
            local file_size=$(ls -lh "$script_path" | awk '{print $5}')
            if [ -x "$script_path" ]; then
                printf "%-5s %-35s ${GREEN}%-10s${NC} %-15s\n" "$key" "$tool_name" "可执行" "$file_size"
            else
                printf "%-5s %-35s ${YELLOW}%-10s${NC} %-15s\n" "$key" "$tool_name" "无权限" "$file_size"
            fi
        else
            printf "%-5s %-35s ${RED}%-10s${NC} %-15s\n" "$key" "$tool_name" "缺失" "N/A"
        fi
    done
}

# 创建桌面快捷方式 (macOS)
create_desktop_shortcuts() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        print_header "创建桌面快捷方式 (macOS)"
        
        local desktop_dir="$HOME/Desktop"
        
        for key in "${!TOOLS[@]}"; do
            IFS='|' read -r script_name tool_name description <<< "${TOOLS[$key]}"
            local script_path="$SCRIPT_DIR/$script_name"
            local shortcut_name="Docker-Tool-$key.command"
            local shortcut_path="$desktop_dir/$shortcut_name"
            
            if [ -f "$script_path" ]; then
                cat > "$shortcut_path" << EOF
#!/bin/bash
cd "$SCRIPT_DIR"
"$script_path"
EOF
                chmod +x "$shortcut_path"
                print_success "创建快捷方式：$shortcut_name"
            fi
        done
        
        print_info "桌面快捷方式创建完成"
    else
        print_warning "此功能仅支持 macOS 系统"
    fi
}

# 显示使用帮助
show_help() {
    print_header "Docker 工具启动器使用帮助"
    
    echo -e "${CYAN}用途：${NC}统一管理和启动所有 Docker 学习工具"
    echo -e "${CYAN}位置：${NC}$SCRIPT_DIR"
    echo
    
    echo -e "${YELLOW}可用工具：${NC}"
    for key in $(printf '%s\n' "${!TOOLS[@]}" | sort -n); do
        IFS='|' read -r script_name tool_name description <<< "${TOOLS[$key]}"
        echo -e "  ${GREEN}$key.${NC} $tool_name"
        echo -e "     $description"
        echo
    done
    
    echo -e "${YELLOW}命令行用法：${NC}"
    echo "  $0                    # 显示交互式菜单"
    echo "  $0 [工具编号]         # 直接运行指定工具"
    echo "  $0 status            # 显示工具状态"
    echo "  $0 setup             # 设置脚本权限"
    echo "  $0 help              # 显示此帮助信息"
    echo
    
    echo -e "${YELLOW}示例：${NC}"
    echo "  $0 1                 # 运行 Docker 交互式学习脚本"
    echo "  $0 status            # 检查所有工具状态"
}

# 显示主菜单
show_main_menu() {
    clear
    echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║                    Docker 工具启动器                        ║${NC}"
    echo -e "${BLUE}║                  Docker Tools Launcher                      ║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo
    
    echo -e "${CYAN}📚 可用的 Docker 学习工具：${NC}"
    echo
    
    for key in $(printf '%s\n' "${!TOOLS[@]}" | sort -n); do
        IFS='|' read -r script_name tool_name description <<< "${TOOLS[$key]}"
        local script_path="$SCRIPT_DIR/$script_name"
        
        if [ -f "$script_path" ] && [ -x "$script_path" ]; then
            echo -e "  ${GREEN}$key.${NC} $tool_name"
        else
            echo -e "  ${RED}$key.${NC} $tool_name ${YELLOW}(不可用)${NC}"
        fi
        echo -e "     ${BLUE}$description${NC}"
        echo
    done
    
    echo -e "${CYAN}🔧 管理选项：${NC}"
    echo -e "  ${GREEN}s.${NC} 显示工具状态"
    echo -e "  ${GREEN}p.${NC} 设置脚本权限"
    echo -e "  ${GREEN}i.${NC} 查看工具信息"
    echo -e "  ${GREEN}c.${NC} 创建桌面快捷方式 (macOS)"
    echo -e "  ${GREEN}h.${NC} 显示帮助信息"
    echo -e "  ${GREEN}0.${NC} 退出"
    echo
    echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}"
}

# 主函数
main() {
    # 处理命令行参数
    if [ $# -gt 0 ]; then
        case "$1" in
            "help"|"--help"|"-h")
                show_help
                exit 0
                ;;
            "status")
                show_tools_status
                exit 0
                ;;
            "setup")
                setup_permissions
                exit 0
                ;;
            [1-5])
                if check_script_files; then
                    run_tool "$1"
                else
                    print_error "请先检查脚本文件完整性"
                    exit 1
                fi
                exit 0
                ;;
            *)
                print_error "无效参数：$1"
                show_help
                exit 1
                ;;
        esac
    fi
    
    # 检查脚本文件
    if ! check_script_files; then
        print_error "部分脚本文件缺失，请检查安装"
        exit 1
    fi
    
    # 设置权限
    setup_permissions
    
    # 交互式菜单
    while true; do
        show_main_menu
        read -p "请选择工具或操作 (0-5, s, p, i, c, h): " choice
        
        case "$choice" in
            [1-5])
                run_tool "$choice"
                ;;
            "s"|"S")
                show_tools_status
                ;;
            "p"|"P")
                setup_permissions
                ;;
            "i"|"I")
                read -p "请输入要查看的工具编号 (1-5): " tool_num
                show_tool_info "$tool_num"
                ;;
            "c"|"C")
                create_desktop_shortcuts
                ;;
            "h"|"H")
                show_help
                ;;
            "0")
                echo -e "\n${GREEN}感谢使用 Docker 工具启动器！${NC}"
                echo -e "${BLUE}继续学习 Docker，加油！🐳${NC}\n"
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