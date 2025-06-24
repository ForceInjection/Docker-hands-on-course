#!/bin/bash
# 联合文件系统故障诊断脚本

set -e

echo "=== 联合文件系统故障诊断工具 ==="

# 颜色定义
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# 日志函数
log_error() {
    echo -e "${RED}[错误]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[警告]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[成功]${NC} $1"
}

# 1. 系统环境检查
echo "\n=== 系统环境检查 ==="

# 检查内核版本
KERNEL_VERSION=$(uname -r)
echo "内核版本: $KERNEL_VERSION"

# 检查 OverlayFS 支持
if grep -q overlay /proc/filesystems; then
    log_success "OverlayFS 内核支持: 可用"
else
    log_error "OverlayFS 内核支持: 不可用"
fi

# 检查 Docker 版本
DOCKER_VERSION=$(docker --version 2>/dev/null || echo "未安装")
echo "Docker 版本: $DOCKER_VERSION"

# 检查存储驱动
STORAGE_DRIVER=$(docker info --format '{{.Driver}}' 2>/dev/null || echo "无法获取")
echo "当前存储驱动: $STORAGE_DRIVER"

# 2. 存储空间检查
echo "\n=== 存储空间检查 ==="

DOCKER_ROOT=$(docker info --format '{{.DockerRootDir}}' 2>/dev/null || echo "/var/lib/docker")
echo "Docker 根目录: $DOCKER_ROOT"

# 检查磁盘空间
if [ -d "$DOCKER_ROOT" ]; then
    DISK_USAGE=$(df -h "$DOCKER_ROOT" | tail -1)
    DISK_PERCENT=$(echo "$DISK_USAGE" | awk '{print $5}' | sed 's/%//')
    
    echo "磁盘使用情况:"
    echo "$DISK_USAGE"
    
    if [ "$DISK_PERCENT" -gt 90 ]; then
        log_error "磁盘空间不足 (${DISK_PERCENT}% 已使用)"
    elif [ "$DISK_PERCENT" -gt 80 ]; then
        log_warning "磁盘空间紧张 (${DISK_PERCENT}% 已使用)"
    else
        log_success "磁盘空间充足 (${DISK_PERCENT}% 已使用)"
    fi
else
    log_error "无法访问 Docker 根目录: $DOCKER_ROOT"
fi

# 3. Docker 存储状态检查
echo "\n=== Docker 存储状态检查 ==="

# 检查 Docker 服务状态
if docker info >/dev/null 2>&1; then
    log_success "Docker 服务运行正常"
    
    # 显示存储统计
    echo "\nDocker 存储统计:"
    docker system df
    
    # 检查存储驱动状态
    case $STORAGE_DRIVER in
        "overlay2")
            echo "\n--- OverlayFS 状态检查 ---"
            OVERLAY_DIR="$DOCKER_ROOT/overlay2"
            
            if [ -d "$OVERLAY_DIR" ]; then
                LAYER_COUNT=$(find "$OVERLAY_DIR" -maxdepth 1 -type d 2>/dev/null | wc -l)
                echo "OverlayFS 层数量: $((LAYER_COUNT - 1))"
                
                # 检查是否有损坏的层
                echo "检查损坏的层..."
                BROKEN_LAYERS=0
                find "$OVERLAY_DIR" -maxdepth 1 -type d -name "*" 2>/dev/null | while read layer; do
                    if [ -d "$layer" ] && [ ! -r "$layer" ]; then
                        echo "损坏的层: $layer"
                        BROKEN_LAYERS=$((BROKEN_LAYERS + 1))
                    fi
                done
                
                if [ $BROKEN_LAYERS -eq 0 ]; then
                    log_success "未发现损坏的层"
                else
                    log_error "发现 $BROKEN_LAYERS 个损坏的层"
                fi
            else
                log_error "无法访问 OverlayFS 目录: $OVERLAY_DIR"
            fi
            ;;
        "aufs")
            echo "\n--- AUFS 状态检查 ---"
            log_warning "AUFS 已被弃用，建议升级到 OverlayFS"
            ;;
        "devicemapper")
            echo "\n--- Device Mapper 状态检查 ---"
            # 检查设备映射器状态
            if command -v dmsetup >/dev/null 2>&1; then
                echo "Device Mapper 设备:"
                dmsetup ls | grep docker | head -5
            fi
            ;;
    esac
else
    log_error "Docker 服务未运行或无法访问"
fi

# 4. 容器状态检查
echo "\n=== 容器状态检查 ==="

# 检查问题容器
echo "检查问题容器..."
PROBLEM_CONTAINERS=$(docker ps -a --filter "status=exited" --filter "status=dead" --format "{{.Names}}" | wc -l)

if [ $PROBLEM_CONTAINERS -gt 0 ]; then
    log_warning "发现 $PROBLEM_CONTAINERS 个问题容器"
    echo "问题容器列表:"
    docker ps -a --filter "status=exited" --filter "status=dead" --format "table {{.Names}}\t{{.Status}}\t{{.Image}}"
else
    log_success "未发现问题容器"
fi

# 5. 挂载点检查
echo "\n=== 挂载点检查 ==="

# 检查 OverlayFS 挂载
echo "当前 OverlayFS 挂载:"
OVERLAY_MOUNTS=$(mount | grep overlay | wc -l)
echo "OverlayFS 挂载数量: $OVERLAY_MOUNTS"

if [ $OVERLAY_MOUNTS -gt 0 ]; then
    echo "OverlayFS 挂载详情:"
    mount | grep overlay | head -5
fi

# 检查僵尸挂载
echo "\n检查僵尸挂载..."
ZOMBIE_MOUNTS=$(mount | grep "docker" | grep "(deleted)" | wc -l)
if [ $ZOMBIE_MOUNTS -gt 0 ]; then
    log_warning "发现 $ZOMBIE_MOUNTS 个僵尸挂载"
    mount | grep "docker" | grep "(deleted)"
else
    log_success "未发现僵尸挂载"
fi

# 6. 性能问题检查
echo "\n=== 性能问题检查 ==="

# 检查 I/O 等待
IOWAIT=$(iostat 1 1 | grep "avg-cpu" -A 1 | tail -1 | awk '{print $4}' 2>/dev/null || echo "0")
echo "当前 I/O 等待: ${IOWAIT}%"

if [ "$(echo "$IOWAIT > 20" | bc 2>/dev/null || echo 0)" -eq 1 ]; then
    log_warning "I/O 等待较高，可能存在性能问题"
else
    log_success "I/O 等待正常"
fi

# 检查内存使用
MEMORY_USAGE=$(free | grep Mem | awk '{printf "%.1f", $3/$2 * 100.0}')
echo "内存使用率: ${MEMORY_USAGE}%"

if [ "$(echo "$MEMORY_USAGE > 90" | bc 2>/dev/null || echo 0)" -eq 1 ]; then
    log_error "内存使用率过高"
elif [ "$(echo "$MEMORY_USAGE > 80" | bc 2>/dev/null || echo 0)" -eq 1 ]; then
    log_warning "内存使用率较高"
else
    log_success "内存使用率正常"
fi

# 7. 日志检查
echo "\n=== 日志检查 ==="

# 检查 Docker 日志中的存储相关错误
echo "检查 Docker 日志中的存储错误..."
if command -v journalctl >/dev/null 2>&1; then
    STORAGE_ERRORS=$(journalctl -u docker --since "1 hour ago" | grep -i "storage\|overlay\|mount" | grep -i "error\|failed" | wc -l)
    if [ $STORAGE_ERRORS -gt 0 ]; then
        log_warning "在 Docker 日志中发现 $STORAGE_ERRORS 个存储相关错误"
        echo "最近的错误:"
        journalctl -u docker --since "1 hour ago" | grep -i "storage\|overlay\|mount" | grep -i "error\|failed" | tail -5
    else
        log_success "Docker 日志中未发现存储错误"
    fi
else
    echo "无法访问 systemd 日志"
fi

# 8. 修复建议
echo "\n=== 修复建议 ==="

echo "基于检查结果的修复建议:"

if [ $PROBLEM_CONTAINERS -gt 0 ]; then
    echo "1. 清理问题容器:"
    echo "   docker container prune"
fi

if [ $ZOMBIE_MOUNTS -gt 0 ]; then
    echo "2. 清理僵尸挂载:"
    echo "   重启 Docker 服务: sudo systemctl restart docker"
fi

if [ "$DISK_PERCENT" -gt 80 ]; then
    echo "3. 清理存储空间:"
    echo "   docker system prune -a"
    echo "   docker volume prune"
fi

echo "\n4. 常规维护命令:"
echo "   - 清理未使用的镜像: docker image prune"
echo "   - 清理停止的容器: docker container prune"
echo "   - 清理未使用的卷: docker volume prune"
echo "   - 清理未使用的网络: docker network prune"
echo "   - 完整清理: docker system prune -a --volumes"

echo "\n=== 诊断完成 ==="