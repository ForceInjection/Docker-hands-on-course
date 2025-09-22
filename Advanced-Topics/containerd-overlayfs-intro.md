# containerd 的 Overlay 文件系统简介

在现代容器运行时（如 Docker、containerd、CRI-O）中，**文件系统隔离与高效存储管理**是容器技术的核心。为了实现这一点，Linux 提供的 **OverlayFS** 文件系统被广泛使用。本文将结合一个实际的 `mount` 信息输出，介绍 containerd 中 OverlayFS 的工作原理与目录结构。

## 目录

- [containerd 的 Overlay 文件系统简介](#containerd-的-overlay-文件系统简介)
  - [目录](#目录)
  - [前置知识](#前置知识)
  - [1. OverlayFS 简介](#1-overlayfs-简介)
    - [1.1 核心组件](#11-核心组件)
    - [1.2 工作机制](#12-工作机制)
  - [2. containerd 中的 OverlayFS 实现](#2-containerd-中的-overlayfs-实现)
    - [2.1 挂载方式与参数解析](#21-挂载方式与参数解析)
    - [2.2 文件系统结构组织](#22-文件系统结构组织)
    - [2.3 工作机制与实例演示](#23-工作机制与实例演示)
  - [3. Docker 与 containerd 的 OverlayFS 对比](#3-docker-与-containerd-的-overlayfs-对比)
    - [3.1 Docker 的 OverlayFS 挂载示例](#31-docker-的-overlayfs-挂载示例)
    - [3.2 关键差异对比表](#32-关键差异对比表)
    - [3.3 目录结构对比图](#33-目录结构对比图)
  - [4. 常见问题与故障排查](#4-常见问题与故障排查)
    - [4.1 常见问题诊断](#41-常见问题诊断)
      - [4.1.1 挂载失败问题](#411-挂载失败问题)
      - [4.1.2 性能问题排查](#412-性能问题排查)
  - [5. 实践练习](#5-实践练习)
    - [5.1 手动创建 OverlayFS 挂载](#51-手动创建-overlayfs-挂载)
    - [5.2 containerd 存储监控与分析](#52-containerd-存储监控与分析)
    - [5.3 高级性能优化实践](#53-高级性能优化实践)

---

## 前置知识

在阅读本文档之前，建议您具备以下基础知识：

- **Linux 文件系统基础**：了解文件系统的基本概念和挂载机制
- **容器技术基础**：熟悉 Docker 和容器的基本概念
- **命令行操作**：能够熟练使用 Linux 命令行工具
- **存储系统概念**：理解分层存储和联合文件系统的基本原理

**参考资料**：

- **OverlayFS 官方文档**：[Linux Kernel Documentation - OverlayFS](https://www.kernel.org/doc/Documentation/filesystems/overlayfs.txt)
- **containerd 官方文档**：[containerd.io](https://containerd.io/)
- **Docker 存储驱动文档**：[Docker Storage Drivers](https://docs.docker.com/storage/storagedriver/)
- **Kubernetes CRI 规范**：[Container Runtime Interface](https://kubernetes.io/docs/concepts/architecture/cri/)
- **Linux 文件系统深入理解**：《Understanding the Linux Kernel》第12章

---

## 1. OverlayFS 简介

OverlayFS 是 Linux 内核 3.18+ 版本提供的 **联合挂载（union mount）** 技术，专为容器化场景设计。相比传统文件系统，它具有启动速度快、存储效率高、层级管理灵活等优势。

### 1.1 核心组件

OverlayFS 将多个目录层级合并为单一文件系统视图：

- **lowerdir**：只读基础层，支持多层叠加（如镜像层），按优先级从左到右排列
- **upperdir**：可写增量层，存储容器运行时的所有变更（新增、修改、删除）
- **workdir**：内部工作目录，用于原子操作和临时文件处理，必须与 upperdir 在同一文件系统
- **merged**：统一挂载点，对外提供完整的文件系统视图

### 1.2 工作机制

**写时复制（Copy-on-Write）** 是 OverlayFS 的核心机制：

- **读操作**：按层级优先级查找文件，优先从 upperdir 读取，不存在则从 lowerdir 读取
- **写操作**：首次修改时将文件从 lowerdir 复制到 upperdir，后续修改直接在 upperdir 进行
- **删除操作**：通过在 upperdir 创建 whiteout 文件标记删除，不影响 lowerdir 原文件

---

## 2. containerd 中的 OverlayFS 实现

本章将深入介绍 `containerd` 如何使用 OverlayFS 技术来实现容器的文件系统隔离和高效存储管理。我们将从挂载方式开始，逐步分析文件系统结构组织和具体的工作机制。

### 2.1 挂载方式与参数解析

在 containerd 中，每个容器的文件系统都通过 OverlayFS 挂载。以下是一个实际的挂载信息示例：

```bash
# containerd 的 OverlayFS 挂载示例（为便于阅读，长路径已换行显示）
overlay on /run/containerd/io.containerd.runtime.v2.task/k8s.io/\
2c4e1ad8c4a567a3a486e9ee2b6cdb04997fdeaff7914c50c99c35c62da8cc6d/rootfs \
type overlay (rw,relatime, \
    lowerdir=20307/fs:20306/fs:20305/fs:20304/fs:20303/fs:20302/fs:20301/fs:\
             20300/fs:20299/fs:20298/fs:20297/fs:20296/fs:20295/fs:18619/fs:\
             18618/fs:18617/fs:18616/fs:18615/fs:18614/fs:18613/fs:18612/fs:\
             18611/fs:18610/fs:18609/fs:18608/fs:18607/fs:18606/fs:18605/fs:\
             18589/fs:18588/fs:18587/fs:18585/fs:18584/fs:18582/fs:18578/fs:\
             18577/fs:18575/fs:18574/fs:18573/fs:18572/fs:18571/fs:18570/fs:\
             18569/fs:18568/fs:18551/fs:18550/fs:18549/fs:18548/fs:18547/fs, \
    upperdir=/var/lib/containerd/io.containerd.snapshotter.v1.overlayfs/snapshots/26656/fs, \
    workdir=/var/lib/containerd/io.containerd.snapshotter.v1.overlayfs/snapshots/26656/work)

# 参数详解：
# - lowerdir: 只读层，包含多个镜像层（按优先级从左到右排列）
# - upperdir: 可写层，存储容器运行时的所有变更
# - workdir:  工作目录，OverlayFS 内部使用的临时目录
# - merged:   挂载点，对外暴露的统一文件系统视图（即 rootfs）
```

让我们详细分解这个挂载命令的各个组成部分：

1. **挂载点（merged）**
   `/run/containerd/io.containerd.runtime.v2.task/k8s.io/<container-id>/rootfs`
   → 这是容器的根文件系统路径，容器内部看到的就是这个目录的内容。

2. **lowerdir（只读层）**
   `lowerdir=20307/fs:20306/fs:20305/fs:...:18547/fs`
   → 这些路径代表多个只读层，每个层通常对应容器镜像中的一层（image layer）。数字目录（如 `20307/fs`）是 containerd snapshotter 管理的镜像快照。

3. **upperdir（可写层）**
   `upperdir=/var/lib/containerd/io.containerd.snapshotter.v1.overlayfs/snapshots/26656/fs`
   → 这是容器运行时的可写层，容器对文件的新增、修改、删除操作都会写入这里。

4. **workdir（工作目录）**
   `workdir=/var/lib/containerd/io.containerd.snapshotter.v1.overlayfs/snapshots/26656/work`
   → 这是 OverlayFS 的工作目录，内部用于管理写操作的元数据，用户通常不直接访问。

### 2.2 文件系统结构组织

在 containerd 中，`/var/lib/containerd/io.containerd.snapshotter.v1.overlayfs/snapshots/` 目录下保存了所有镜像层与容器层的数据。这种组织方式体现了 containerd 的 snapshotter 架构设计：

**存储目录结构：**

```text
/var/lib/containerd/
└── io.containerd.snapshotter.v1.overlayfs/
    └── snapshots/
        ├── 20307/                   # 镜像层快照（只读）
        │   └── fs/                  # 镜像层内容
        ├── 20306/                   # 镜像层快照（只读）
        │   └── fs/                  # 镜像层内容
        ├── 26656/                   # 容器层快照（可写）
        │   ├── fs/                  # upperdir（可写层）
        │   └── work/                # workdir（工作目录）
        └── ...

/run/containerd/                     # 运行时目录
└── io.containerd.runtime.v2.task/
    └── k8s.io/
        └── <container-id>/
            └── rootfs/              # 挂载点（merged）
```

**层级关系说明：**

- **镜像层（Image Layers）**：存放在只读的 `lowerdir` 路径下，每个数字 ID 对应一个 snapshot。这些层是不可变的，可以被多个容器共享。
- **容器层（Container Layer）**：唯一可写的 `upperdir`，保存容器运行时产生的所有数据变更。
- **工作目录（Work Directory）**：用于 OverlayFS 的内部维护，包括写时复制操作的临时文件和元数据。

**snapshotter 管理机制：**

containerd 使用 snapshotter 接口来管理这些存储层，提供了统一的快照管理能力：

- **快照创建**：基于父快照创建新的快照
- **快照挂载**：将快照挂载为 OverlayFS
- **快照清理**：删除不再使用的快照
- **快照链管理**：维护快照之间的父子关系

### 2.3 工作机制与实例演示

OverlayFS 的核心工作机制是写时复制（Copy-on-Write），下面通过具体实例来说明这一过程：

**读操作示例：**

假设容器镜像中有 `/etc/hosts` 文件：

```bash
# 容器访问 /etc/hosts 时的查找顺序：
# 1. 首先检查 upperdir 中是否存在该文件
# 2. 如果不存在，则从 lowerdir 中按优先级顺序查找
# 3. 返回找到的第一个匹配文件
```

**写操作示例：**

当容器执行文件修改操作时：

```bash
# 容器执行：echo "127.0.0.1 myapp" >> /etc/hosts

# OverlayFS 的处理流程：
# 1. 检查 upperdir 中是否已存在 /etc/hosts
# 2. 如果不存在，从 lowerdir 中找到原始文件
# 3. 将原始文件完整拷贝到 upperdir 中
# 4. 在 upperdir 的副本上执行修改操作
# 5. 后续访问将直接读取 upperdir 中的版本
```

**删除操作示例：**

```bash
# 容器执行：rm /etc/hosts

# OverlayFS 的处理流程：
# 1. 如果文件在 upperdir 中，直接删除
# 2. 如果文件只在 lowerdir 中，创建 whiteout 文件
# 3. whiteout 文件会隐藏 lowerdir 中的同名文件
# 4. 容器看到的效果是文件被删除了
```

**性能优化机制：**

1. **延迟复制**：只有在实际写入时才进行文件复制
2. **共享只读层**：多个容器可以共享相同的镜像层
3. **增量存储**：只存储变更的文件，不影响原始镜像层

这种设计确保了多个容器可以高效地共享相同的 `lowerdir`，避免重复存储，同时每个容器都拥有独立的写入空间，实现了存储效率和隔离性的平衡。

---

## 3. Docker 与 containerd 的 OverlayFS 对比

为了更好地理解不同容器运行时的实现差异，我们来对比一下 Docker 和 containerd 在 OverlayFS 使用上的区别。

### 3.1 Docker 的 OverlayFS 挂载示例

下面是 Docker 的典型挂载信息：

```bash
# Docker 的 OverlayFS 挂载示例
overlay on /var/lib/docker/overlay2/604cf1c6f3ee72cf6ff4d2ec957631ea21a028c7898feb8dd45cfd4f6f919240/merged \
type overlay (rw,relatime, \
    lowerdir=/var/lib/docker/overlay2/l/J5SVTUIX6XFPTEN5YSAOVUD7LS:/var/lib/docker/overlay2/l/AW75PLTPHK2W7NVTLP26CD5PC6:/var/lib/docker/overlay2/l/MAXCREMZ4AGH77EORBHHJ6PR7Q:..., \
    upperdir=/var/lib/docker/overlay2/604cf1c6f3ee72cf6ff4d2ec957631ea21a028c7898feb8dd45cfd4f6f919240/diff, \
    workdir=/var/lib/docker/overlay2/604cf1c6f3ee72cf6ff4d2ec957631ea21a028c7898feb8dd45cfd4f6f919240/work)
```

### 3.2 关键差异对比表

| 组件 | containerd | Docker | 说明 |
|------|------------|--------|------|
| **挂载点** | `/run/containerd/io.containerd.runtime.v2.task/k8s.io/<container-id>/rootfs` | `/var/lib/docker/overlay2/<container-id>/merged` | containerd 使用运行时路径，Docker 使用存储路径 |
| **lowerdir 路径** | `/var/lib/containerd/.../snapshots/<id>/fs` | `/var/lib/docker/overlay2/l/<short-link>` | containerd 使用数字 ID，Docker 使用短链接 |
| **upperdir 路径** | `/var/lib/containerd/.../snapshots/<id>/fs` | `/var/lib/docker/overlay2/<container-id>/diff` | containerd 使用 snapshotter 管理，Docker 使用容器 ID 目录 |
| **workdir 路径** | `/var/lib/containerd/.../snapshots/<id>/work` | `/var/lib/docker/overlay2/<container-id>/work` | 两者都在各自的管理目录下 |

### 3.3 目录结构对比图

**containerd 的目录结构：**

```text
/var/lib/containerd/
└── io.containerd.snapshotter.v1.overlayfs/
    └── snapshots/
        ├── 20307/                   # 镜像层快照
        │   ├── fs/                  # 镜像层内容
        │   └── work/                # 工作目录（如果是容器层）
        ├── 20306/                   # 镜像层快照
        │   └── fs/                  # 镜像层内容
        ├── 26656/                   # 容器层快照
        │   ├── fs/                  # upperdir（可写层）
        │   └── work/                # workdir（工作目录）
        └── ...

/run/containerd/                     # 运行时目录
└── io.containerd.runtime.v2.task/
    └── k8s.io/
        └── <container-id>/
            └── rootfs/              # 挂载点（merged）
```

**Docker 的目录结构：**

```text
/var/lib/docker/overlay2/
├── <container-id>/                  # 容器专用目录
│   ├── merged/                      # 挂载点（对外暴露的合并视图）
│   ├── diff/                        # upperdir（可写层）
│   ├── work/                        # workdir（工作目录）
│   └── link                         # 指向短链接的符号链接
├── l/                               # 短链接目录（解决路径长度问题）
│   ├── J5SVTUIX6XFPTEN5YSAOVUD7LS -> ../layer1/diff
│   ├── AW75PLTPHK2W7NVTLP26CD5PC6 -> ../layer2/diff
│   └── ...
├── layer1/                          # 镜像层1
│   └── diff/                        # 镜像层内容
├── layer2/                          # 镜像层2
│   └── diff/                        # 镜像层内容
└── ...
```

---

## 4. 常见问题与故障排查

### 4.1 常见问题诊断

#### 4.1.1 挂载失败问题

**问题现象：**

```bash
# 容器启动失败，出现挂载错误
failed to mount overlay: invalid argument
```

**排查步骤：**

**1. 检查内核支持**：

```bash
# 检查内核是否支持 OverlayFS
grep overlay /proc/filesystems

# 检查内核版本（建议 4.0+）
uname -r
```

**2. 检查存储空间**：

```bash
# 检查 containerd 存储目录的磁盘空间使用情况
# -h 参数以人类可读格式显示大小（KB、MB、GB）
df -h /var/lib/containerd

# 检查 Docker 存储目录的磁盘空间使用情况（如果同时使用 Docker）
df -h /var/lib/docker

# 检查 inode 使用情况，防止因 inode 耗尽导致的文件创建失败
# -i 参数显示 inode 使用统计信息
df -i /var/lib/containerd
```

**3. 检查目录权限**：

```bash
# 检查 containerd OverlayFS snapshotter 存储目录的权限和所有者
# 确保 containerd 进程有读写权限
ls -la /var/lib/containerd/io.containerd.snapshotter.v1.overlayfs/

# 检查 containerd 运行时目录权限
# 该目录存储容器的运行时挂载点和临时文件
ls -la /run/containerd/
```

#### 4.1.2 性能问题排查

**问题现象：**

- 容器启动缓慢
- 文件 I/O 性能差

**排查方法：**

**1. 检查镜像层数量**：

```bash
# 使用 containerd 客户端查看所有镜像列表
# 过多的镜像层会影响 OverlayFS 的读取性能
ctr images list

# 使用 Docker 查看特定镜像的层历史（如果使用 Docker）
# 将 <image-name> 替换为实际的镜像名称
docker history "<image-name>"

# 性能建议：镜像层数不超过 20 层，以避免过深的目录嵌套
# 可通过多阶段构建和层合并来减少层数
```

**2. 监控存储性能**：

```bash
# 使用 iostat 监控磁盘 I/O 性能指标
# -x 显示扩展统计信息，1 表示每秒刷新一次
# 关注 %util（磁盘利用率）和 await（平均等待时间）
iostat -x 1

# 使用 iotop 实时查看各进程的 I/O 使用情况
# -o 只显示有 I/O 活动的进程，便于定位性能瓶颈
iotop -o
```

**3. 检查挂载选项**：

```bash
# 查看当前挂载选项
mount | grep overlay

# 推荐的性能优化选项
# index=off: 禁用索引功能，减少元数据开销
# metacopy=off: 禁用元数据复制，提升性能
```

---

## 5. 实践练习

**环境要求：**

- Linux 内核版本 ≥ 4.0（支持 OverlayFS）
- root 权限或 sudo 访问权限
- containerd 已安装并运行
- 建议在测试环境中执行

### 5.1 手动创建 OverlayFS 挂载

```bash
#!/bin/bash
# OverlayFS 手动挂载演示脚本
# 注意：此脚本需要 root 权限，仅在测试环境中使用

# 检查内核是否支持 OverlayFS
if ! grep -q overlay /proc/filesystems; then
    echo "错误：内核不支持 OverlayFS" >&2
    exit 1
fi

# 定义测试目录路径
TEST_DIR="/tmp/overlay-test"

# 创建 OverlayFS 所需的目录结构
# lower1, lower2: 只读层目录
# upper: 可写层目录
# work: OverlayFS 工作目录（必须为空）
# merged: 挂载点目录（对外提供统一视图）
mkdir -p "${TEST_DIR}"/{lower1,lower2,upper,work,merged}

# 在只读层添加测试文件，模拟镜像层内容
echo "from lower1" > "${TEST_DIR}/lower1/file1.txt"
echo "from lower2" > "${TEST_DIR}/lower2/file2.txt"
echo "shared content" > "${TEST_DIR}/lower1/shared.txt"

# 手动挂载 OverlayFS
# -t overlay: 指定文件系统类型
# lowerdir: 只读层，多个层用冒号分隔，右侧优先级更高
# upperdir: 可写层，存储所有修改
# workdir: 工作目录，用于原子操作
if sudo mount -t overlay overlay \
  -o "lowerdir=${TEST_DIR}/lower1:${TEST_DIR}/lower2,upperdir=${TEST_DIR}/upper,workdir=${TEST_DIR}/work" \
  "${TEST_DIR}/merged"; then
    echo "✓ OverlayFS 挂载成功"
else
    echo "✗ 挂载失败，请检查权限和目录状态" >&2
    exit 1
fi

# 验证挂载结果，查看合并后的文件系统内容
echo "=== 挂载点内容 ==="
ls -la "${TEST_DIR}/merged/"

# 测试写时复制机制
# 修改来自 lower 层的文件（触发 CoW）
echo "modified in upper" >> "${TEST_DIR}/merged/file1.txt"
# 创建新文件（直接写入 upper 层）
echo "new file" > "${TEST_DIR}/merged/newfile.txt"

# 验证文件分布，查看 upper 层的变更内容
echo "=== upperdir 变更内容 ==="
find "${TEST_DIR}/upper" -type f -exec echo "文件: {}" \; -exec cat {} \;

# 清理挂载点（重要：避免资源泄露）
if sudo umount "${TEST_DIR}/merged"; then
    echo "✓ 清理完成"
else
    echo "✗ 卸载失败" >&2
fi
```

### 5.2 containerd 存储监控与分析

```bash
#!/bin/bash
# containerd 存储状态监控脚本

# 检查 containerd 服务状态
if ! systemctl is-active --quiet containerd; then
    echo "警告：containerd 服务未运行" >&2
fi

# 快照使用情况分析
echo "=== Snapshotter 状态 ==="
ctr snapshots list | head -10
echo "总快照数量: $(ctr snapshots list -q | wc -l)"

# 存储空间使用分析
CONTAINERD_ROOT="/var/lib/containerd"
if [ -d "${CONTAINERD_ROOT}" ]; then
    echo "=== 存储使用统计 ==="
    du -sh "${CONTAINERD_ROOT}/io.containerd.snapshotter.v1.overlayfs/" 2>/dev/null || echo "无法访问存储目录"
    
    # 检查磁盘空间
    df -h "${CONTAINERD_ROOT}" | tail -1 | awk '{print "可用空间: " $4 " (使用率: " $5 ")"}'
fi

# 镜像层分析
echo "=== 镜像使用情况 ==="
ctr images list | awk 'NR>1 {size+=$3} END {print "镜像总数: " NR-1 "\n估算总大小: " size/1024/1024 " MB"}'
```

### 5.3 高级性能优化实践

**1. 多容器共享层验证**：

```bash
# 创建两个基于相同镜像的容器，验证层共享
ctr run --rm docker.io/library/alpine:latest test1 sh -c "echo 'Container 1' && sleep 5" &
ctr run --rm docker.io/library/alpine:latest test2 sh -c "echo 'Container 2' && sleep 5" &

# 检查共享的 lowerdir（应该相同）
mount | grep overlay | grep -E "(test1|test2)" | awk -F'lowerdir=' '{print $2}' | awk -F',' '{print $1}'
```

**2. 性能基准测试**：

```bash
# 文件 I/O 性能测试
TEST_FILE="/tmp/overlay-test/merged/benchmark.dat"
echo "=== 写入性能测试 ==="
time dd if=/dev/zero of="${TEST_FILE}" bs=1M count=100 2>&1 | grep -E "(copied|MB/s)"

echo "=== 读取性能测试 ==="
time dd if="${TEST_FILE}" of=/dev/null bs=1M 2>&1 | grep -E "(copied|MB/s)"
```

**3. 优化配置示例**：

```toml
# /etc/containerd/config.toml 性能优化配置
[plugins."io.containerd.snapshotter.v1.overlayfs"]
  # 禁用慢速 chown 操作
  slow_chown = false
  
  # 优化挂载选项（减少元数据开销）
  mount_options = ["index=off", "metacopy=off", "volatile"]
  
  # 启用异步 I/O
  async_remove = true
```

**验证方法：**

- 使用 `mount | grep overlay` 确认挂载参数
- 通过 `iostat -x 1` 监控 I/O 性能变化
- 使用 `ctr snapshots usage <snapshot-id>` 检查空间使用

---
