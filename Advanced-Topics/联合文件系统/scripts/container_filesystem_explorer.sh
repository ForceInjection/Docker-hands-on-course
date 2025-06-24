#!/bin/bash
# 容器文件系统探索脚本

set -e

if [ $# -eq 0 ]; then
    echo "用法: $0 <容器名称或ID>"
    echo "示例: $0 my-container"
    exit 1
fi

CONTAINER=$1

echo "=== 容器文件系统探索: $CONTAINER ==="

# 1. 检查容器是否存在
if ! docker ps -a --format "{{.Names}}" | grep -q "^${CONTAINER}$"; then
    if ! docker ps -a --format "{{.ID}}" | grep -q "^${CONTAINER}"; then
        echo "错误: 容器 '$CONTAINER' 不存在"
        exit 1
    fi
fi

# 2. 获取容器详细信息
echo "\n=== 容器基本信息 ==="
docker inspect $CONTAINER --format '
容器ID: {{.Id}}
镜像: {{.Config.Image}}
状态: {{.State.Status}}
创建时间: {{.Created}}
存储驱动: {{.GraphDriver.Name}}'

# 3. 分析存储驱动信息
echo "\n=== 存储驱动详情 ==="
STORAGE_DRIVER=$(docker inspect $CONTAINER --format '{{.GraphDriver.Name}}')
echo "存储驱动: $STORAGE_DRIVER"

case $STORAGE_DRIVER in
    "overlay2")
        echo "\n--- OverlayFS 层信息 ---"
        LOWER_DIR=$(docker inspect $CONTAINER --format '{{.GraphDriver.Data.LowerDir}}')
        UPPER_DIR=$(docker inspect $CONTAINER --format '{{.GraphDriver.Data.UpperDir}}')
        MERGED_DIR=$(docker inspect $CONTAINER --format '{{.GraphDriver.Data.MergedDir}}')
        WORK_DIR=$(docker inspect $CONTAINER --format '{{.GraphDriver.Data.WorkDir}}')
        
        echo "下层目录: $LOWER_DIR"
        echo "上层目录: $UPPER_DIR"
        echo "合并目录: $MERGED_DIR"
        echo "工作目录: $WORK_DIR"
        
        # 分析层数量
        LAYER_COUNT=$(echo "$LOWER_DIR" | tr ':' '\n' | wc -l)
        echo "层数量: $LAYER_COUNT"
        
        # 显示各层大小
        echo "\n--- 各层大小分析 ---"
        if [ -d "$UPPER_DIR" ]; then
            UPPER_SIZE=$(du -sh "$UPPER_DIR" 2>/dev/null | cut -f1 || echo "N/A")
            echo "上层大小: $UPPER_SIZE"
        fi
        
        echo "\n--- 下层目录详情 ---"
        IFS=':' read -ra LAYERS <<< "$LOWER_DIR"
        for i in "${!LAYERS[@]}"; do
            layer="${LAYERS[$i]}"
            if [ -d "$layer" ]; then
                size=$(du -sh "$layer" 2>/dev/null | cut -f1 || echo "N/A")
                echo "层 $((i+1)): $size - $layer"
            fi
        done
        ;;
    "aufs")
        echo "\n--- AUFS 层信息 ---"
        docker inspect $CONTAINER --format '{{range $key, $value := .GraphDriver.Data}}{{$key}}: {{$value}}{{"\n"}}{{end}}'
        ;;
    "devicemapper")
        echo "\n--- Device Mapper 信息 ---"
        docker inspect $CONTAINER --format '{{range $key, $value := .GraphDriver.Data}}{{$key}}: {{$value}}{{"\n"}}{{end}}'
        ;;
    *)
        echo "\n--- 通用存储信息 ---"
        docker inspect $CONTAINER --format '{{range $key, $value := .GraphDriver.Data}}{{$key}}: {{$value}}{{"\n"}}{{end}}'
        ;;
esac

# 4. 挂载点信息
echo "\n=== 挂载点信息 ==="
docker inspect $CONTAINER --format '{{range .Mounts}}类型: {{.Type}}, 源: {{.Source}}, 目标: {{.Destination}}, 读写: {{.RW}}{{"\n"}}{{end}}'

# 5. 文件系统使用情况
echo "\n=== 容器内文件系统使用情况 ==="
if docker ps --format "{{.Names}}" | grep -q "^${CONTAINER}$"; then
    echo "容器正在运行，获取实时文件系统信息..."
    docker exec $CONTAINER df -h 2>/dev/null || echo "无法获取文件系统信息（容器可能没有 df 命令）"
else
    echo "容器未运行，无法获取实时文件系统信息"
fi

# 6. 层文件变化分析
echo "\n=== 层文件变化分析 ==="
if [ "$STORAGE_DRIVER" = "overlay2" ] && [ -d "$UPPER_DIR" ]; then
    echo "上层目录文件列表:"
    find "$UPPER_DIR" -type f 2>/dev/null | head -20 || echo "无法访问上层目录"
    
    echo "\n上层目录总文件数:"
    find "$UPPER_DIR" -type f 2>/dev/null | wc -l || echo "无法统计"
fi

# 7. 容器大小分析
echo "\n=== 容器大小分析 ==="
docker ps -s --filter "name=$CONTAINER" --format "table {{.Names}}\t{{.Size}}"

echo "\n=== 探索完成 ==="