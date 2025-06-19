# Docker 核心命令与实用工具

> 📚 **学习目标**：掌握 Docker 日常操作中最重要的命令，提升容器管理效率，并通过实用脚本工具加速学习进程

## 📋 目录

- [1. Docker 基本命令大全](#1-docker-基本命令大全)
  - [1.1 容器管理命令](#11-容器管理命令)
  - [1.2 镜像管理命令](#12-镜像管理命令)
  - [1.3 网络和存储命令](#13-网络和存储命令)
  - [1.4 监控和调试命令](#14-监控和调试命令)
  - [1.5 实用技巧](#15-实用技巧)
  - [1.6 常见问题解答](#16-常见问题解答)
  - [1.7 学习建议](#17-学习建议)
  - [1.8 总结](#18-总结)
- [2. Docker 学习脚本工具](#2-docker-学习脚本工具)
  - [2.1 脚本列表](#21-脚本列表)
  - [2.2 使用方法](#22-使用方法)
  - [2.3 学习路径建议](#23-学习路径建议)
  - [2.4 安全注意事项](#24-安全注意事项)
  - [2.5 故障排除](#25-故障排除)
  - [2.6 日志和报告](#26-日志和报告)

---

## 1. Docker 基本命令大全

### 1.1 容器管理命令

#### 1.1.1 基础操作

|命令|描述|示例|使用场景|
|---|---|---|---|
|`docker ps`|列出所有正在运行的容器|`docker ps`|快速查看当前活跃容器|
|`docker ps -a`|列出所有容器（包括已停止的）|`docker ps -a`|查看所有容器历史状态|
|`docker ps -q`|仅显示容器ID|`docker ps -q`|批量操作时获取ID列表|
|`docker stop 容器ID`|优雅停止容器（发送SIGTERM信号）|`docker stop web-app`|正常关闭应用服务|
|`docker kill 容器ID`|强制停止容器（发送SIGKILL信号）|`docker kill web-app`|紧急停止无响应容器|
|`docker start 容器ID`|启动已停止的容器|`docker start web-app`|重新启动之前的容器|
|`docker restart 容器ID`|重启容器|`docker restart web-app`|应用配置更改后重启|
|`docker pause 容器ID`|暂停容器中的所有进程|`docker pause web-app`|临时暂停容器运行|
|`docker unpause 容器ID`|恢复暂停的容器|`docker unpause web-app`|恢复暂停的容器运行|
|`docker rm 容器ID`|删除已停止的容器|`docker rm web-app`|清理不需要的容器|
|`docker rm -f 容器ID`|强制删除容器（⚠️ 谨慎使用）|`docker rm -f web-app`|强制清理运行中的容器|
|`docker prune`|删除所有停止的容器|`docker container prune`|批量清理停止的容器|

#### 1.1.2 容器交互

|命令|描述|示例|使用场景|
|---|---|---|---|
|`docker exec -it 容器名 /bin/bash`|进入容器交互式终端|`docker exec -it web-app /bin/bash`|调试和故障排除|
|`docker exec -it 容器名 /bin/sh`|进入容器（Alpine Linux）|`docker exec -it web-app /bin/sh`|轻量级镜像的交互|
|`docker exec 容器名 命令`|在容器中执行单个命令|`docker exec web-app ls -la`|快速执行容器内命令|
|`docker attach 容器名`|连接到容器的主进程|`docker attach web-app`|查看容器主进程输出|
|`docker cp 文件路径 容器名:目标路径`|复制文件到容器|`docker cp ./app.jar web-app:/app/`|传输文件到容器|
|`docker cp 容器名:文件路径 目标路径`|从容器复制文件|`docker cp web-app:/logs ./logs`|从容器获取文件|

### 1.2 镜像管理命令

#### 1.2.1 镜像操作

|命令|描述|示例|使用场景|
|---|---|---|---|
|`docker images`|列出所有本地镜像|`docker images`|查看本地镜像库|
|`docker images -q`|仅显示镜像ID|`docker images -q`|批量操作镜像|
|`docker pull 镜像名`|拉取镜像|`docker pull nginx:latest`|获取最新镜像|
|`docker pull 镜像名:标签`|拉取指定版本镜像|`docker pull nginx:1.21-alpine`|获取特定版本|
|`docker push 镜像名`|推送镜像到仓库|`docker push myapp:v1.0`|发布自定义镜像|
|`docker rmi 镜像ID`|删除镜像|`docker rmi nginx:latest`|清理不需要的镜像|
|`docker rmi -f 镜像ID`|强制删除镜像|`docker rmi -f nginx:latest`|强制清理镜像|
|`docker image prune`|删除悬空镜像|`docker image prune`|清理无标签镜像|
|`docker image prune -a`|删除所有未使用镜像|`docker image prune -a`|深度清理镜像|

#### 1.2.2 镜像构建

|命令|描述|示例|使用场景|
|---|---|---|---|
|`docker build -t 镜像名 .`|从Dockerfile构建镜像|`docker build -t myapp:v1.0 .`|构建自定义应用镜像|
|`docker build -f Dockerfile路径 -t 镜像名 .`|指定Dockerfile构建|`docker build -f docker/Dockerfile -t myapp .`|使用非标准Dockerfile|
|`docker build --no-cache -t 镜像名 .`|无缓存构建|`docker build --no-cache -t myapp .`|确保完全重新构建|
|`docker tag 源镜像 目标镜像`|为镜像添加标签|`docker tag myapp:latest myapp:v1.0`|版本管理和发布|

#### 1.2.3 仓库操作

|命令|描述|示例|使用场景|
|---|---|---|---|
|`docker login`|登录Docker Hub|`docker login`|推送镜像前的认证|
|`docker login -u 用户名 -p 密码`|使用凭据登录|`docker login -u myuser -p mypass`|自动化脚本登录|
|`docker logout`|注销Docker Hub|`docker logout`|安全退出登录|

### 1.3 网络和存储命令

#### 1.3.1 网络管理

|命令|描述|示例|使用场景|
|---|---|---|---|
|`docker network ls`|列出所有网络|`docker network ls`|查看网络配置|
|`docker network create 网络名`|创建自定义网络|`docker network create mynet`|容器间通信|
|`docker network inspect 网络名`|查看网络详细信息|`docker network inspect bridge`|网络故障排除|
|`docker network connect 网络名 容器名`|连接容器到网络|`docker network connect mynet web-app`|动态网络配置|
|`docker network disconnect 网络名 容器名`|断开容器网络连接|`docker network disconnect mynet web-app`|网络隔离|
|`docker port 容器名`|查看端口映射|`docker port web-app`|检查端口配置|

#### 1.3.2 数据卷管理

|命令|描述|示例|使用场景|
|---|---|---|---|
|`docker volume ls`|列出所有数据卷|`docker volume ls`|查看存储配置|
|`docker volume create 卷名`|创建数据卷|`docker volume create mydata`|持久化数据存储|
|`docker volume inspect 卷名`|查看卷详细信息|`docker volume inspect mydata`|存储故障排除|
|`docker volume rm 卷名`|删除数据卷|`docker volume rm mydata`|清理存储空间|
|`docker volume prune`|删除未使用的卷|`docker volume prune`|批量清理存储|

### 1.4 监控和调试命令

#### 1.4.1 系统信息

|命令|描述|示例|使用场景|
|---|---|---|---|
|`docker version`|显示Docker版本信息|`docker version`|环境检查|
|`docker info`|显示系统信息|`docker info`|系统状态检查|
|`docker system df`|显示磁盘使用情况|`docker system df`|存储空间管理|
|`docker system prune`|清理系统资源|`docker system prune`|释放存储空间|
|`docker system prune -a`|深度清理系统|`docker system prune -a`|彻底清理环境|

#### 1.4.2 容器监控

|命令|描述|示例|使用场景|
|---|---|---|---|
|`docker stats`|实时显示容器资源使用|`docker stats`|性能监控|
|`docker stats 容器名`|监控特定容器|`docker stats web-app`|单容器性能分析|
|`docker top 容器名`|显示容器进程|`docker top web-app`|进程状态检查|
|`docker logs 容器名`|查看容器日志|`docker logs web-app`|故障排除|
|`docker logs -f 容器名`|实时跟踪日志|`docker logs -f web-app`|实时日志监控|
|`docker logs --tail 100 容器名`|查看最后100行日志|`docker logs --tail 100 web-app`|快速日志检查|
|`docker inspect 容器名`|查看容器详细信息|`docker inspect web-app`|深度配置检查|

### 1.5 实用技巧

#### 1.5.1 批量操作

```bash
# 停止所有运行中的容器
docker stop $(docker ps -q)

# 删除所有停止的容器
docker rm $(docker ps -aq)

# 删除所有镜像
docker rmi $(docker images -q)

# 删除所有悬空镜像
docker image prune

# 一键清理系统（谨慎使用）
docker system prune -a --volumes
```

#### 1.5.2 常用组合命令

```bash
# 构建并运行
docker build -t myapp . && docker run -d --name myapp-container myapp

# 停止并删除容器
docker stop myapp-container && docker rm myapp-container

# 查看容器IP地址
docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' 容器名

# 进入容器并查看环境变量
docker exec -it 容器名 env
```

#### 1.5.3 别名设置

```bash
# 添加到 ~/.bashrc 或 ~/.zshrc
alias dps='docker ps'
alias dpa='docker ps -a'
alias di='docker images'
alias dex='docker exec -it'
alias dlog='docker logs -f'
```

### 1.6 常见问题解答

#### Q: 如何安全地停止容器？

**A:** 优先使用 `docker stop`，它会发送 SIGTERM 信号让应用优雅关闭。只有在容器无响应时才使用 `docker kill`。

#### Q: 容器删除失败怎么办？

**A:** 确保容器已停止：`docker stop 容器名`，然后再删除：`docker rm 容器名`。如果仍然失败，使用 `docker rm -f 容器名`。

#### Q: 如何查看容器的详细配置？

**A:** 使用 `docker inspect 容器名` 可以查看完整的容器配置信息，包括网络、存储、环境变量等。

#### Q: 磁盘空间不足怎么办？

**A:** 定期清理：

1. `docker container prune` - 清理停止的容器
2. `docker image prune` - 清理悬空镜像
3. `docker volume prune` - 清理未使用的卷
4. `docker system prune -a` - 深度清理（谨慎使用）

#### Q: 如何备份容器数据？

**A:** 使用数据卷或绑定挂载，然后通过 `docker cp` 命令或直接备份挂载目录。

### 1.7 学习建议

1. **循序渐进**：从基础命令开始，逐步掌握高级功能
2. **实践为主**：在安全环境中多练习各种命令组合
3. **理解原理**：了解每个命令背后的工作机制
4. **安全意识**：谨慎使用带 `-f` 参数的强制命令
5. **自动化思维**：学会编写脚本批量处理容器操作

> 💡 **提示**：建议将常用命令制作成备忘单，方便日常查阅使用。

### 1.8 总结

掌握这些 Docker 命令是容器化开发的基础。记住以下要点：

- 🔍 **查看状态**：`docker ps`、`docker images`、`docker stats`
- 🎮 **容器控制**：`docker start/stop/restart`
- 🗑️ **清理资源**：`docker rm/rmi`、`docker prune`
- 🔧 **调试工具**：`docker exec`、`docker logs`、`docker inspect`
- 🌐 **网络存储**：`docker network`、`docker volume`

通过熟练使用这些命令，你将能够高效地管理 Docker 环境，提升开发和运维效率。

> 📖 **下一步学习**：建议继续学习 Docker Compose 和 Dockerfile 编写，进一步提升容器化技能。

---

## 2. Docker 学习脚本工具

本目录包含了一系列专为 Docker 学习设计的实用脚本，帮助用户从基础到进阶全面掌握 Docker 技术。

### 2.1 脚本列表

#### 2.1.1 🚀 Docker 工具启动器 (`docker-tools-launcher.sh`)

**主启动脚本，统一管理所有工具**：

- **功能**：提供图形化菜单，统一启动和管理所有 Docker 学习工具
- **特点**：
  - 自动检查脚本完整性
  - 自动设置执行权限
  - 支持命令行直接调用
  - 提供工具状态检查
  - 支持创建桌面快捷方式 (macOS)

```bash
# 启动主菜单
./docker-tools-launcher.sh

# 直接运行指定工具
./docker-tools-launcher.sh 1

# 查看工具状态
./docker-tools-launcher.sh status

# 显示帮助
./docker-tools-launcher.sh help
```

#### 2.1.2 📚 Docker 交互式学习脚本 (`docker-learning-scripts.sh`)

**分类学习 Docker 命令**：

- **功能**：提供分类的 Docker 命令学习和练习
- **包含模块**：
  - 基础容器操作
  - 镜像管理
  - 网络和存储
  - 监控和调试
  - 批量操作
  - 环境清理
  - 系统信息查看

- **特点**：
  - 交互式菜单导航
  - 实时命令演示
  - 安全的学习环境
  - 详细的命令说明

#### 2.1.3 🔍 Docker 命令速查工具 (`docker-quick-reference.sh`)

**快速查找和测试 Docker 命令**：

- **功能**：提供 Docker 命令快速参考和测试
- **包含内容**：
  - 容器管理命令
  - 镜像管理命令
  - 网络管理命令
  - 存储管理命令
  - 监控调试命令
  - 系统管理命令
  - 常用命令组合
  - 命令测试模式
  - 生成命令备忘单

- **特点**：
  - 按类别组织命令
  - 提供使用示例
  - 交互式测试模式
  - 自动生成 Markdown 备忘单

#### 2.1.4 🧪 Docker 实践练习实验室 (`docker-practice-lab.sh`)

**提供实际的练习环境和场景**：

- **功能**：创建真实的 Docker 练习环境
- **练习项目**：
  1. 基础容器操作
  2. Web 服务部署
  3. 数据卷管理
  4. 网络管理
  5. Docker Compose 多服务部署
  6. 镜像优化实践

- **特点**：
  - 自动创建练习环境
  - 提供完整的示例文件
  - 实际的容器部署体验
  - 详细的操作日志
  - 安全的清理机制

#### 2.1.5 🔧 Docker 故障排除工具 (`docker-troubleshoot.sh`)

**诊断和解决常见问题**：

- **功能**：全面诊断 Docker 环境和常见问题
- **诊断模块**：
  - 系统环境检查
  - Docker 安装检查
  - Docker 服务状态
  - 容器状态诊断
  - 镜像诊断
  - 网络诊断
  - 存储诊断
  - 性能诊断
  - 常见问题检查

- **特点**：
  - 生成详细诊断报告
  - 提供修复建议
  - 快速修复工具
  - 支持完整系统诊断

#### 2.1.6 🚀 Docker 自动化部署工具 (`docker-auto-deploy.sh`)

**一键部署常见应用**：

- **功能**：快速部署常用的 Docker 应用
- **支持应用**：
  - Nginx Web 服务器
  - MySQL 数据库
  - Redis 缓存服务
  - WordPress 博客系统
  - Portainer Docker 管理界面
  - Jenkins CI/CD 服务
  - 监控栈 (Prometheus + Grafana)

- **特点**：
  - 一键式部署
  - 自动配置优化
  - 提供访问信息
  - 支持批量管理
  - 完整的清理功能

### 2.2 使用方法

#### 2.2.1 快速开始

1. **确保 Docker 已安装并运行**

   ```bash
   docker --version
   docker info
   ```

2. **进入脚本目录**

   ```bash
   cd /Users/wangtianqing/Project/docker-fundamentals/05-Essential-Docker-Commands
   ```

3. **启动工具启动器**

   ```bash
   ./docker-tools-launcher.sh
   ```

#### 2.2.2 单独使用脚本

每个脚本都可以独立运行：

```bash
# Docker 交互式学习
./docker-learning-scripts.sh

# 命令速查工具
./docker-quick-reference.sh

# 实践练习实验室
./docker-practice-lab.sh

# 故障排除工具
./docker-troubleshoot.sh

# 自动化部署工具
./docker-auto-deploy.sh
```

### 2.3 学习路径建议

#### 2.3.1 初学者路径

1. **docker-learning-scripts.sh** - 学习基础命令
2. **docker-quick-reference.sh** - 熟悉命令速查
3. **docker-practice-lab.sh** - 进行实际练习

#### 2.3.2 进阶用户路径

1. **docker-practice-lab.sh** - 高级练习场景
2. **docker-auto-deploy.sh** - 学习自动化部署
3. **docker-troubleshoot.sh** - 掌握故障排除

#### 2.3.3 运维人员路径

1. **docker-troubleshoot.sh** - 系统诊断
2. **docker-auto-deploy.sh** - 生产部署
3. **docker-quick-reference.sh** - 日常运维参考

### 2.4 安全注意事项

1. **权限管理**：脚本会自动设置必要的执行权限
2. **数据安全**：练习环境使用独立的数据卷，不会影响系统数据
3. **网络安全**：所有服务默认只监听本地端口
4. **清理机制**：提供完整的环境清理功能

### 2.5 故障排除

#### 2.5.1 常见问题

1. **权限不足**

   ```bash
   chmod +x *.sh
   ```

2. **Docker 未运行**

   ```bash
   # macOS
   open -a Docker
   
   # Linux
   sudo systemctl start docker
   ```

3. **端口冲突**
   - 检查端口占用：`lsof -i :端口号`
   - 修改脚本中的端口配置

4. **脚本执行错误**
   - 使用故障排除工具：`./docker-troubleshoot.sh`
   - 查看详细错误信息

### 2.6 日志和报告

- **练习日志**：`~/docker-practice-lab/practice.log`
- **部署日志**：`~/docker-deployments/deployment.log`
- **诊断报告**：`docker-diagnostic-report-*.txt`
