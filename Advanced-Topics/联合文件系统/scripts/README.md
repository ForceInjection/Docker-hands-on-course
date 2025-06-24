# 联合文件系统脚本集合

本目录包含了联合文件系统教程中使用的所有脚本文件，每个脚本都有特定的功能和用途。

## 脚本列表

### 1. OverlayFS 实验脚本

**文件**: `overlayfs_experiment.sh`
**功能**: 手动创建和操作 OverlayFS 文件系统
**用途**: 理解 OverlayFS 的基本工作原理

```bash
# 使用方法
chmod +x overlayfs_experiment.sh
sudo ./overlayfs_experiment.sh
```

**注意**: 需要 root 权限来挂载文件系统

### 2. Docker 存储驱动性能测试

**文件**: `docker_storage_benchmark.sh`
**功能**: 测试不同存储驱动的性能表现
**用途**: 比较存储驱动性能，优化选择

```bash
# 使用方法
chmod +x docker_storage_benchmark.sh
./docker_storage_benchmark.sh
```

**依赖**: Docker, bc 命令

### 3. 容器文件系统探索工具

**文件**: `container_filesystem_explorer.sh`
**功能**: 深入分析容器的文件系统结构
**用途**: 调试和理解容器存储机制

```bash
# 使用方法
chmod +x container_filesystem_explorer.sh
./container_filesystem_explorer.sh <容器名称或ID>

# 示例
./container_filesystem_explorer.sh my-nginx
```

### 4. 性能监控脚本

**文件**: `performance_monitor.sh`
**功能**: 监控 OverlayFS 的实时性能指标
**用途**: 性能分析和优化

```bash
# 使用方法
chmod +x performance_monitor.sh
sudo ./performance_monitor.sh
```

**注意**: 需要 root 权限，依赖 iostat 命令

### 5. 存储空间分析工具

**文件**: `storage_analyzer.sh`
**功能**: 分析 Docker 存储空间使用情况
**用途**: 存储优化和清理建议

```bash
# 使用方法
chmod +x storage_analyzer.sh
./storage_analyzer.sh
```

### 6. 故障诊断工具

**文件**: `troubleshoot_storage.sh`
**功能**: 诊断联合文件系统相关问题
**用途**: 故障排查和系统健康检查

```bash
# 使用方法
chmod +x troubleshoot_storage.sh
./troubleshoot_storage.sh
```

### 7. 高效镜像构建脚本

**文件**: `build_optimized_image.sh`
**功能**: 构建优化的容器镜像
**用途**: 实践镜像构建最佳实践

```bash
# 使用方法
chmod +x build_optimized_image.sh
./build_optimized_image.sh [版本] [仓库地址]

# 示例
./build_optimized_image.sh v1.0 registry.example.com
```

### 8. 容器存储监控系统

**文件**: `storage_monitor.py`
**功能**: Web 界面的实时存储监控系统
**用途**: 可视化监控容器存储状态

```bash
# 安装依赖
pip install docker flask psutil

# 运行监控系统
python3 storage_monitor.py

# 访问 http://localhost:5000 查看监控界面
```

**模板文件**: `templates/dashboard.html` - 监控界面模板

## 使用建议

### 学习顺序

1. 首先运行 `overlayfs_experiment.sh` 理解基本概念
2. 使用 `container_filesystem_explorer.sh` 探索实际容器
3. 通过 `docker_storage_benchmark.sh` 了解性能特征
4. 使用 `storage_analyzer.sh` 分析存储使用
5. 运行 `storage_monitor.py` 进行实时监控

### 故障排查

- 遇到问题时首先运行 `troubleshoot_storage.sh`
- 根据诊断结果采取相应的修复措施
- 使用 `performance_monitor.sh` 监控修复效果

### 生产环境使用

- 定期运行 `storage_analyzer.sh` 进行存储清理
- 使用 `storage_monitor.py` 建立监控系统
- 采用 `build_optimized_image.sh` 的最佳实践构建镜像

## 系统要求

### 基本要求

- Linux 系统 (推荐 Ubuntu 18.04+)
- Docker 18.09+
- Bash 4.0+

### 可选依赖

- `bc` - 数学计算
- `iostat` - I/O 监控
- `attr` - 扩展属性查看
- `python3` - 监控系统
- `pip` - Python 包管理

### 权限要求

- 部分脚本需要 sudo 权限
- Docker 用户组权限
- 文件系统读写权限

## 注意事项

1. **安全性**: 生产环境使用前请仔细审查脚本内容
2. **备份**: 运行修改性操作前请备份重要数据
3. **测试**: 建议先在测试环境中验证脚本功能
4. **权限**: 注意脚本的权限要求，避免不必要的 root 权限
5. **清理**: 实验后及时清理测试数据和挂载点

## 故障排除

### 常见问题

1. **权限不足**

   ```bash
   # 解决方案
   sudo chmod +x script_name.sh
   sudo ./script_name.sh
   ```

2. **命令未找到**

   ```bash
   # 安装缺失的工具
   sudo apt-get update
   sudo apt-get install sysstat attr bc
   ```

3. **Docker 连接失败**

   ```bash
   # 检查 Docker 服务
   sudo systemctl status docker
   sudo systemctl start docker
   ```

4. **挂载失败**

   ```bash
   # 检查内核支持
   grep overlay /proc/filesystems
   
   # 清理旧挂载
   sudo umount /path/to/mount
   ```

---
