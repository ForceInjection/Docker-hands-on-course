#!/bin/bash
# Docker 存储驱动性能测试脚本

set -e

echo "=== Docker 存储驱动性能测试 ==="

# 测试参数
TEST_IMAGE="alpine:latest"
TEST_SIZE="100M"
TEST_COUNT=10

# 获取当前存储驱动
CURRENT_DRIVER=$(docker info --format '{{.Driver}}')
echo "当前存储驱动: $CURRENT_DRIVER"

# 1. 容器启动时间测试
echo "\n=== 容器启动时间测试 ==="
echo "测试 $TEST_COUNT 次容器启动时间..."

total_time=0
for i in $(seq 1 $TEST_COUNT); do
    start_time=$(date +%s.%N)
    container_id=$(docker run -d $TEST_IMAGE sleep 1)
    docker wait $container_id > /dev/null
    end_time=$(date +%s.%N)
    
    duration=$(echo "$end_time - $start_time" | bc)
    total_time=$(echo "$total_time + $duration" | bc)
    
    docker rm $container_id > /dev/null
    echo "第 $i 次: ${duration}s"
done

avg_time=$(echo "scale=3; $total_time / $TEST_COUNT" | bc)
echo "平均启动时间: ${avg_time}s"

# 2. 文件 I/O 性能测试
echo "\n=== 文件 I/O 性能测试 ==="

# 写性能测试
echo "测试写性能..."
write_start=$(date +%s.%N)
docker run --rm -v /tmp:/test $TEST_IMAGE sh -c "
    dd if=/dev/zero of=/test/testfile bs=1M count=100 2>/dev/null
"
write_end=$(date +%s.%N)
write_time=$(echo "$write_end - $write_start" | bc)
echo "写入 100MB 耗时: ${write_time}s"

# 读性能测试
echo "测试读性能..."
read_start=$(date +%s.%N)
docker run --rm -v /tmp:/test $TEST_IMAGE sh -c "
    dd if=/test/testfile of=/dev/null bs=1M 2>/dev/null
"
read_end=$(date +%s.%N)
read_time=$(echo "$read_end - $read_start" | bc)
echo "读取 100MB 耗时: ${read_time}s"

# 清理测试文件
rm -f /tmp/testfile

# 3. 镜像层操作性能
echo "\n=== 镜像层操作性能测试 ==="

# 创建测试 Dockerfile
cat > /tmp/Dockerfile.test << 'EOF'
FROM alpine:latest
RUN echo "layer1" > /layer1.txt
RUN echo "layer2" > /layer2.txt
RUN echo "layer3" > /layer3.txt
RUN echo "layer4" > /layer4.txt
RUN echo "layer5" > /layer5.txt
EOF

echo "测试镜像构建时间..."
build_start=$(date +%s.%N)
docker build -t test-layers -f /tmp/Dockerfile.test /tmp > /dev/null 2>&1
build_end=$(date +%s.%N)
build_time=$(echo "$build_end - $build_start" | bc)
echo "构建 5 层镜像耗时: ${build_time}s"

# 清理
docker rmi test-layers > /dev/null 2>&1
rm -f /tmp/Dockerfile.test

# 4. 存储空间使用分析
echo "\n=== 存储空间使用分析 ==="
docker system df

echo "\n=== 详细存储信息 ==="
docker system df -v | head -20

echo "\n=== 性能测试完成 ==="
echo "存储驱动: $CURRENT_DRIVER"
echo "平均启动时间: ${avg_time}s"
echo "写入性能: ${write_time}s (100MB)"
echo "读取性能: ${read_time}s (100MB)"
echo "构建性能: ${build_time}s (5层)"