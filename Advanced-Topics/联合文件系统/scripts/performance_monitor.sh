#!/bin/bash
# OverlayFS 性能监控脚本

set -e

echo "=== OverlayFS 性能监控 ==="

# 配置参数
TEST_DIR="/tmp/overlayfs-perf-test"
TEST_SIZE="1G"
MONITOR_DURATION=60
SAMPLE_INTERVAL=5

# 清理函数
cleanup() {
    echo "\n清理测试环境..."
    sudo umount "$TEST_DIR/merged" 2>/dev/null || true
    rm -rf "$TEST_DIR"
}

trap cleanup EXIT

# 1. 创建测试环境
echo "创建测试环境..."
mkdir -p "$TEST_DIR"/{lower,upper,work,merged}

# 在下层创建一些基础文件
echo "创建基础文件..."
for i in {1..100}; do
    echo "Base file $i content" > "$TEST_DIR/lower/file$i.txt"
done

# 挂载 OverlayFS
echo "挂载 OverlayFS..."
sudo mount -t overlay overlay \
    -o lowerdir="$TEST_DIR/lower",upperdir="$TEST_DIR/upper",workdir="$TEST_DIR/work" \
    "$TEST_DIR/merged"

echo "OverlayFS 挂载完成"

# 2. I/O 性能测试
echo "\n=== I/O 性能测试 ==="

# 顺序写测试
echo "顺序写测试..."
time_start=$(date +%s.%N)
dd if=/dev/zero of="$TEST_DIR/merged/sequential_write.dat" bs=1M count=100 2>/dev/null
time_end=$(date +%s.%N)
seq_write_time=$(echo "$time_end - $time_start" | bc)
echo "顺序写 100MB 耗时: ${seq_write_time}s"

# 顺序读测试
echo "顺序读测试..."
time_start=$(date +%s.%N)
dd if="$TEST_DIR/merged/sequential_write.dat" of=/dev/null bs=1M 2>/dev/null
time_end=$(date +%s.%N)
seq_read_time=$(echo "$time_end - $time_start" | bc)
echo "顺序读 100MB 耗时: ${seq_read_time}s"

# 随机写测试
echo "随机写测试..."
time_start=$(date +%s.%N)
for i in {1..1000}; do
    echo "Random data $RANDOM" > "$TEST_DIR/merged/random_$i.txt"
done
time_end=$(date +%s.%N)
rand_write_time=$(echo "$time_end - $time_start" | bc)
echo "创建 1000 个小文件耗时: ${rand_write_time}s"

# 3. 内存使用监控
echo "\n=== 内存使用监控 ==="

# 获取初始内存使用
initial_memory=$(free -m | awk 'NR==2{print $3}')
echo "初始内存使用: ${initial_memory}MB"

# 执行大量文件操作
echo "执行大量文件操作..."
for i in {1..5000}; do
    cp "$TEST_DIR/lower/file1.txt" "$TEST_DIR/merged/copy_$i.txt"
    echo "Modified content $i" >> "$TEST_DIR/merged/copy_$i.txt"
done

# 获取操作后内存使用
final_memory=$(free -m | awk 'NR==2{print $3}')
memory_diff=$((final_memory - initial_memory))
echo "操作后内存使用: ${final_memory}MB"
echo "内存增长: ${memory_diff}MB"

# 4. 存储空间效率分析
echo "\n=== 存储空间效率分析 ==="

# 分析各层大小
echo "各层大小分析:"
lower_size=$(du -sh "$TEST_DIR/lower" | cut -f1)
upper_size=$(du -sh "$TEST_DIR/upper" | cut -f1)
merged_size=$(du -sh "$TEST_DIR/merged" | cut -f1)

echo "下层大小: $lower_size"
echo "上层大小: $upper_size"
echo "合并视图大小: $merged_size"

# 计算文件数量
lower_files=$(find "$TEST_DIR/lower" -type f | wc -l)
upper_files=$(find "$TEST_DIR/upper" -type f | wc -l)
merged_files=$(find "$TEST_DIR/merged" -type f | wc -l)

echo "\n文件数量统计:"
echo "下层文件数: $lower_files"
echo "上层文件数: $upper_files"
echo "合并视图文件数: $merged_files"

# 5. 实时监控
echo "\n=== 实时性能监控 (${MONITOR_DURATION}秒) ==="
echo "时间戳,CPU使用率,内存使用(MB),磁盘IO读(KB/s),磁盘IO写(KB/s)"

for ((i=0; i<MONITOR_DURATION; i+=SAMPLE_INTERVAL)); do
    timestamp=$(date '+%H:%M:%S')
    
    # CPU 使用率
    cpu_usage=$(top -l 1 -n 0 | grep "CPU usage" | awk '{print $3}' | sed 's/%//' || echo "0")
    
    # 内存使用
    memory_usage=$(free -m | awk 'NR==2{print $3}' || echo "0")
    
    # 磁盘 I/O (简化版本，实际环境可能需要更复杂的监控)
    disk_read=$(iostat -d 1 1 | tail -1 | awk '{print $3}' 2>/dev/null || echo "0")
    disk_write=$(iostat -d 1 1 | tail -1 | awk '{print $4}' 2>/dev/null || echo "0")
    
    echo "$timestamp,$cpu_usage,$memory_usage,$disk_read,$disk_write"
    
    # 在后台执行一些文件操作来产生负载
    (
        for j in {1..10}; do
            echo "Load test $i-$j" > "$TEST_DIR/merged/load_$i_$j.txt"
        done
    ) &
    
    sleep $SAMPLE_INTERVAL
done

wait  # 等待后台任务完成

# 6. 性能总结
echo "\n=== 性能测试总结 ==="
echo "顺序写性能: ${seq_write_time}s (100MB)"
echo "顺序读性能: ${seq_read_time}s (100MB)"
echo "随机写性能: ${rand_write_time}s (1000个文件)"
echo "内存开销: ${memory_diff}MB"
echo "存储效率: 下层($lower_size) + 上层($upper_size) = 总计"

echo "\n=== 监控完成 ==="