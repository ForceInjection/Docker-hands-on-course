#!/bin/bash
# 存储空间效率分析脚本

set -e

echo "=== Docker 存储空间效率分析 ==="

# 1. 基础存储信息
echo "\n=== 基础存储信息 ==="
docker system df

echo "\n=== 详细存储信息 ==="
docker system df -v

# 2. 镜像层分析
echo "\n=== 镜像层分析 ==="

# 获取所有镜像
echo "分析镜像层共享情况..."
docker images --format "table {{.Repository}}:{{.Tag}}\t{{.ID}}\t{{.Size}}" | head -20

echo "\n=== 镜像层详细信息 ==="
# 分析前5个镜像的层信息
docker images --format "{{.Repository}}:{{.Tag}}" | head -5 | while read image; do
    echo "\n--- 镜像: $image ---"
    docker history "$image" --format "table {{.ID}}\t{{.Size}}\t{{.CreatedBy}}" | head -10
done

# 3. 容器存储分析
echo "\n=== 容器存储分析 ==="

# 显示容器大小
echo "容器大小统计:"
docker ps -a -s --format "table {{.Names}}\t{{.Image}}\t{{.Size}}"

# 4. 存储驱动分析
echo "\n=== 存储驱动分析 ==="
STORAGE_DRIVER=$(docker info --format '{{.Driver}}')
DOCKER_ROOT=$(docker info --format '{{.DockerRootDir}}')

echo "存储驱动: $STORAGE_DRIVER"
echo "Docker 根目录: $DOCKER_ROOT"

case $STORAGE_DRIVER in
    "overlay2")
        echo "\n--- OverlayFS 存储分析 ---"
        OVERLAY_DIR="$DOCKER_ROOT/overlay2"
        
        if [ -d "$OVERLAY_DIR" ]; then
            echo "OverlayFS 目录: $OVERLAY_DIR"
            
            # 统计层数量
            LAYER_COUNT=$(find "$OVERLAY_DIR" -maxdepth 1 -type d | wc -l)
            echo "总层数: $((LAYER_COUNT - 1))"
            
            # 分析层大小分布
            echo "\n层大小分布 (前10个最大的层):"
            find "$OVERLAY_DIR" -maxdepth 1 -type d -exec du -sh {} \; 2>/dev/null | \
                sort -hr | head -10
            
            # 分析总大小
            TOTAL_SIZE=$(du -sh "$OVERLAY_DIR" 2>/dev/null | cut -f1)
            echo "\nOverlayFS 总大小: $TOTAL_SIZE"
        else
            echo "无法访问 OverlayFS 目录: $OVERLAY_DIR"
        fi
        ;;
    "aufs")
        echo "\n--- AUFS 存储分析 ---"
        AUFS_DIR="$DOCKER_ROOT/aufs"
        if [ -d "$AUFS_DIR" ]; then
            echo "AUFS 目录: $AUFS_DIR"
            du -sh "$AUFS_DIR"/* 2>/dev/null | sort -hr | head -10
        fi
        ;;
    "devicemapper")
        echo "\n--- Device Mapper 存储分析 ---"
        DEVICEMAPPER_DIR="$DOCKER_ROOT/devicemapper"
        if [ -d "$DEVICEMAPPER_DIR" ]; then
            echo "Device Mapper 目录: $DEVICEMAPPER_DIR"
            du -sh "$DEVICEMAPPER_DIR"/* 2>/dev/null | sort -hr | head -10
        fi
        ;;
esac

# 5. 重复数据分析
echo "\n=== 重复数据分析 ==="

# 分析镜像层的重复情况
echo "分析镜像层重复情况..."
echo "镜像ID,层数,总大小"
docker images --format "{{.ID}}" | while read image_id; do
    if [ ! -z "$image_id" ]; then
        layer_count=$(docker history "$image_id" --format "{{.ID}}" | wc -l)
        size=$(docker images --format "{{.Size}}" --filter "id=$image_id" | head -1)
        echo "$image_id,$layer_count,$size"
    fi
done | head -10

# 6. 清理建议
echo "\n=== 清理建议 ==="

# 检查悬空镜像
DANGLING_IMAGES=$(docker images -f "dangling=true" -q | wc -l)
echo "悬空镜像数量: $DANGLING_IMAGES"

# 检查未使用的镜像
UNUSED_IMAGES=$(docker images --format "{{.ID}}" | while read img; do
    if [ -z "$(docker ps -a --filter ancestor="$img" -q)" ]; then
        echo "$img"
    fi
done | wc -l)
echo "未使用的镜像数量: $UNUSED_IMAGES"

# 检查停止的容器
STOPPED_CONTAINERS=$(docker ps -a -f "status=exited" -q | wc -l)
echo "停止的容器数量: $STOPPED_CONTAINERS"

# 检查未使用的卷
UNUSED_VOLUMES=$(docker volume ls -f "dangling=true" -q | wc -l)
echo "未使用的卷数量: $UNUSED_VOLUMES"

echo "\n=== 清理命令建议 ==="
echo "清理悬空镜像: docker image prune"
echo "清理停止的容器: docker container prune"
echo "清理未使用的卷: docker volume prune"
echo "清理未使用的网络: docker network prune"
echo "清理所有未使用的资源: docker system prune -a"

# 7. 存储优化建议
echo "\n=== 存储优化建议 ==="

echo "1. 镜像构建优化:"
echo "   - 使用多阶段构建减少最终镜像大小"
echo "   - 合并 RUN 指令减少层数"
echo "   - 使用 .dockerignore 排除不必要的文件"
echo "   - 选择合适的基础镜像"

echo "\n2. 运行时优化:"
echo "   - 定期清理未使用的资源"
echo "   - 监控存储使用情况"
echo "   - 使用适当的存储驱动"

echo "\n3. 存储驱动选择:"
case $STORAGE_DRIVER in
    "overlay2")
        echo "   - 当前使用 OverlayFS，性能良好"
        echo "   - 适合大多数生产环境"
        ;;
    "aufs")
        echo "   - 当前使用 AUFS，考虑升级到 OverlayFS"
        echo "   - AUFS 在新版本中已被弃用"
        ;;
    "devicemapper")
        echo "   - 当前使用 Device Mapper"
        echo "   - 在支持的系统上考虑使用 OverlayFS"
        ;;
esac

echo "\n=== 分析完成 ==="