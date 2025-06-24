#!/bin/bash
# OverlayFS 手动实验脚本

set -e

echo "=== OverlayFS 手动实验 ==="

# 1. 创建实验目录结构
echo "创建实验目录..."
mkdir -p overlay-demo/{lower1,lower2,upper,work,merged}
cd overlay-demo

# 2. 在下层目录中创建文件
echo "创建下层文件..."
echo "This is file1 from lower1" > lower1/file1.txt
echo "This is file2 from lower1" > lower1/file2.txt
echo "This is file3 from lower2" > lower2/file3.txt
echo "This is file2 from lower2" > lower2/file2.txt  # 与 lower1 中的 file2.txt 同名

# 3. 挂载 OverlayFS
echo "挂载 OverlayFS..."
sudo mount -t overlay overlay \
    -o lowerdir=lower2:lower1,upperdir=upper,workdir=work \
    merged

echo "OverlayFS 挂载完成！"

# 4. 查看合并后的文件系统
echo "\n=== 查看合并后的文件系统 ==="
ls -la merged/
echo "\n=== 文件内容 ==="
for file in merged/*.txt; do
    echo "--- $(basename $file) ---"
    cat "$file"
done

# 5. 测试写操作
echo "\n=== 测试写操作 ==="
echo "This is a new file" > merged/newfile.txt
echo "Modified content" >> merged/file1.txt

echo "查看上层目录变化："
ls -la upper/

# 6. 测试删除操作
echo "\n=== 测试删除操作 ==="
rm merged/file3.txt
echo "查看上层目录中的 whiteout 文件："
ls -la upper/

# 7. 查看文件属性
echo "\n=== 查看文件扩展属性 ==="
getfattr -d upper/* 2>/dev/null || echo "需要安装 attr 包来查看扩展属性"

echo "\n=== 实验完成 ==="
echo "要清理实验环境，请运行："
echo "sudo umount merged && cd .. && rm -rf overlay-demo"