# 📥 从 Docker Hub 拉取和运行镜像

> 学习如何从 Docker Hub 拉取镜像并运行容器的完整流程

## 📋 本章学习目标

- 掌握 Docker Hub 的基本使用方法
- 学会搜索、拉取和管理 Docker 镜像
- 理解容器的生命周期管理
- 掌握容器的启动、停止、重启操作
- 学会容器的监控和调试技巧
- 了解多平台镜像的兼容性处理

## 🏪 Docker Hub 简介

### 什么是 Docker Hub？

**Docker Hub** 是 Docker 官方提供的云端镜像仓库服务，包含：

- 🌟 **官方镜像**：由 Docker 官方维护的高质量镜像
- 👥 **社区镜像**：由开发者社区贡献的镜像
- 🔒 **私有仓库**：企业和个人的私有镜像存储
- 🤖 **自动构建**：与 GitHub/Bitbucket 集成的自动构建功能

### 镜像命名规范

```
[registry]/[namespace]/[repository]:[tag]

示例：
- nginx:latest                    # 官方镜像
- mysql:8.0                       # 官方镜像带版本
- stacksimplify/app:1.0.0         # 用户镜像
- docker.io/library/ubuntu:20.04  # 完整格式
```

## 🔐 步骤 1：验证环境并登录 Docker Hub

### 验证 Docker 安装

```bash
# 检查 Docker 版本
docker version

# 查看 Docker 系统信息
docker info

# 检查 Docker 服务状态
docker system info
```

### 登录 Docker Hub

```bash
# 登录到 Docker Hub
docker login

# 输入用户名和密码
# Username: your-dockerhub-username
# Password: your-dockerhub-password

# 验证登录状态
docker system info | grep Username
```

### 预期输出

```bash
$ docker version
Client: Docker Engine - Community
 Version:           24.0.6
 API version:       1.43
 Go version:        go1.20.7
 Git commit:        ed223bc
 Built:             Mon Sep  4 12:28:49 2023
 OS/Arch:           darwin/arm64
 Context:           default

Server: Docker Desktop 4.24.0 (122432)
 Engine:
  Version:          24.0.6
  API version:      1.43 (minimum version 1.12)
  Go version:       go1.20.7
  Git commit:       1a79695
  Built:            Mon Sep  4 12:28:49 2023
  OS/Arch:          linux/arm64
  Experimental:     false
```

## 🔍 步骤 2：搜索和拉取镜像

### 搜索镜像

```bash
# 搜索官方 nginx 镜像
docker search nginx

# 搜索特定用户的镜像
docker search stacksimplify

# 限制搜索结果数量
docker search --limit 5 python
```

### 拉取镜像

```bash
# 拉取示例应用镜像
docker pull stacksimplify/dockerintro-springboot-helloworld-rest-api:1.0.0-RELEASE

# 拉取最新版本（默认 latest 标签）
docker pull nginx

# 拉取特定版本
docker pull nginx:1.27-alpine

# 拉取所有标签
docker pull --all-tags nginx
```

### 查看本地镜像

```bash
# 列出所有本地镜像
docker images

# 查看镜像详细信息
docker image inspect stacksimplify/dockerintro-springboot-helloworld-rest-api:1.0.0-RELEASE

# 查看镜像历史
docker history stacksimplify/dockerintro-springboot-helloworld-rest-api:1.0.0-RELEASE
```

## 🚀 步骤 3：运行容器

### 基本运行命令

```bash
# 运行示例应用
docker run --name app1 -p 80:8080 -d stacksimplify/dockerintro-springboot-helloworld-rest-api:1.0.0-RELEASE

# 命令参数解释：
# --name app1        : 为容器指定名称
# -p 80:8080         : 端口映射（主机端口:容器端口）
# -d                 : 后台运行（detached 模式）
# 最后是镜像名称和标签
```

### 高级运行选项

```bash
# 运行并自动删除容器（退出时）
docker run --rm --name temp-app -p 8080:8080 nginx

# 运行并挂载数据卷
docker run -d --name app-with-volume \
  -p 80:8080 \
  -v /host/path:/container/path \
  stacksimplify/dockerintro-springboot-helloworld-rest-api:1.0.0-RELEASE

# 设置环境变量
docker run -d --name app-with-env \
  -p 80:8080 \
  -e ENV_VAR=value \
  -e ANOTHER_VAR=another_value \
  stacksimplify/dockerintro-springboot-helloworld-rest-api:1.0.0-RELEASE

# 限制资源使用
docker run -d --name app-limited \
  -p 80:8080 \
  --memory=512m \
  --cpus=0.5 \
  stacksimplify/dockerintro-springboot-helloworld-rest-api:1.0.0-RELEASE
```

## 🌐 步骤 4：访问应用程序

### 测试应用连接

```bash
# 使用 curl 测试
curl http://localhost/hello

# 使用 wget 测试
wget -qO- http://localhost/hello

# 在浏览器中访问
# http://localhost/hello
# http://localhost:80/hello
```

### 预期响应

```json
{
  "message": "Hello World from Spring Boot Application",
  "timestamp": "2023-10-01T10:30:00.000+00:00",
  "version": "1.0.0-RELEASE"
}
```

### 健康检查

```bash
# 检查应用健康状态
curl http://localhost/actuator/health

# 查看应用信息
curl http://localhost/actuator/info
```

## 📊 步骤 5：容器管理和监控

### 查看容器状态

```bash
# 列出运行中的容器
docker ps

# 列出所有容器（包括已停止的）
docker ps -a

# 只显示容器 ID
docker ps -q

# 显示最近创建的容器
docker ps -l

# 自定义输出格式
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
```

### 容器资源监控

```bash
# 实时查看容器资源使用情况
docker stats

# 查看特定容器的资源使用
docker stats app1

# 只显示一次统计信息
docker stats --no-stream app1
```

### 查看容器日志

```bash
# 查看容器日志
docker logs app1

# 实时跟踪日志
docker logs -f app1

# 查看最近的日志行
docker logs --tail 50 app1

# 显示时间戳
docker logs -t app1

# 查看特定时间段的日志
docker logs --since "2023-10-01T10:00:00" app1
```

## 🔧 步骤 6：容器交互和调试

### 连接到容器终端

```bash
# 进入运行中的容器
docker exec -it app1 /bin/bash

# 如果容器没有 bash，使用 sh
docker exec -it app1 /bin/sh

# 在容器中执行单个命令
docker exec app1 ls -la /app

# 以 root 用户身份进入容器
docker exec -it --user root app1 /bin/bash
```

### 容器内部调试

```bash
# 在容器内部执行的命令示例

# 查看容器内部进程
ps aux

# 查看网络配置
ip addr show

# 查看环境变量
env

# 查看应用日志
tail -f /var/log/application.log

# 测试网络连接
ping google.com

# 退出容器
exit
```

### 文件传输

```bash
# 从容器复制文件到主机
docker cp app1:/app/config.properties ./config.properties

# 从主机复制文件到容器
docker cp ./new-config.properties app1:/app/config.properties

# 复制整个目录
docker cp app1:/app/logs ./container-logs
```

## ⚡ 步骤 7：容器生命周期管理

### 停止和启动容器

```bash
# 优雅停止容器（发送 SIGTERM 信号）
docker stop app1

# 强制停止容器（发送 SIGKILL 信号）
docker kill app1

# 启动已停止的容器
docker start app1

# 重启容器
docker restart app1

# 暂停容器（冻结所有进程）
docker pause app1

# 恢复暂停的容器
docker unpause app1
```

### 批量操作

```bash
# 停止所有运行中的容器
docker stop $(docker ps -q)

# 启动所有已停止的容器
docker start $(docker ps -aq)

# 重启所有容器
docker restart $(docker ps -aq)
```

## 🗑️ 步骤 8：清理资源

### 删除容器

```bash
# 删除已停止的容器
docker rm app1

# 强制删除运行中的容器
docker rm -f app1

# 删除多个容器
docker rm app1 app2 app3

# 删除所有已停止的容器
docker container prune

# 删除所有容器（包括运行中的）
docker rm -f $(docker ps -aq)
```

### 删除镜像

```bash
# 查看本地镜像
docker images

# 删除特定镜像
docker rmi stacksimplify/dockerintro-springboot-helloworld-rest-api:1.0.0-RELEASE

# 通过镜像 ID 删除
docker rmi <image-id>

# 强制删除镜像
docker rmi -f <image-id>

# 删除未使用的镜像
docker image prune

# 删除所有未使用的镜像
docker image prune -a
```

### 系统清理

```bash
# 清理所有未使用的资源
docker system prune

# 清理所有资源（包括未使用的镜像）
docker system prune -a

# 查看 Docker 磁盘使用情况
docker system df
```

## 🍎 Apple Silicon (M1/M2) 兼容性处理

### 平台兼容性问题

如果您使用的是搭载 Apple Silicon（M1、M2 等）的 Mac，可能会遇到平台兼容性问题：

```bash
# 常见警告信息
WARNING: The requested image's platform (linux/amd64) does not match 
the detected host platform (linux/arm64/v8) and no specific platform was requested
```

### 解决方案

#### 方法 1：指定平台拉取

```bash
# 明确指定 AMD64 平台
docker pull --platform linux/amd64 stacksimplify/dockerintro-springboot-helloworld-rest-api:1.0.0-RELEASE

# 运行时指定平台
docker run --platform linux/amd64 --name app1 -p 80:8080 -d \
  stacksimplify/dockerintro-springboot-helloworld-rest-api:1.0.0-RELEASE
```

#### 方法 2：使用多架构镜像

```bash
# 查找支持 ARM64 的替代镜像
docker search --filter is-official=true nginx

# 使用官方多架构镜像
docker pull nginx:latest  # 自动选择合适的架构
```

#### 方法 3：启用实验性功能

```bash
# 在 Docker Desktop 中启用实验性功能
# Settings > Docker Engine > 添加以下配置
{
  "experimental": true,
  "buildkit": true
}
```

### Apple Silicon 预期输出

```bash
$ docker pull stacksimplify/dockerintro-springboot-helloworld-rest-api:1.0.0-RELEASE
1.0.0-RELEASE: Pulling from stacksimplify/dockerintro-springboot-helloworld-rest-api
WARNING: The requested image's platform (linux/amd64) does not match the detected host platform (linux/arm64/v8)
5d0da3dc9764: Pull complete
74ddd0ec08fa: Pull complete
...
Status: Downloaded newer image for stacksimplify/dockerintro-springboot-helloworld-rest-api:1.0.0-RELEASE

$ docker run --name app1 -p 80:8080 -d stacksimplify/dockerintro-springboot-helloworld-rest-api:1.0.0-RELEASE
WARNING: The requested image's platform (linux/amd64) does not match the detected host platform (linux/arm64/v8)
7a8c9b2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0b

$ curl http://localhost/hello
{"message":"Hello World from Spring Boot Application"}
```

> ⚠️ **注意**：警告信息是正常的，容器仍然可以正常工作，这得益于 Docker 的模拟功能。

## 🔍 故障排除指南

### 常见问题及解决方案

#### 问题 1：端口已被占用

```bash
# 错误信息
Error: bind: address already in use

# 解决方案
# 1. 查找占用端口的进程
lsof -i :80
netstat -tulpn | grep :80

# 2. 使用不同端口
docker run --name app1 -p 8080:8080 -d <image-name>

# 3. 停止占用端口的容器
docker stop $(docker ps -q --filter "publish=80")
```

#### 问题 2：容器启动失败

```bash
# 查看容器日志
docker logs app1

# 查看容器详细信息
docker inspect app1

# 以交互模式运行进行调试
docker run -it --name debug-app <image-name> /bin/bash
```

#### 问题 3：网络连接问题

```bash
# 检查容器网络
docker network ls
docker network inspect bridge

# 测试容器间连接
docker exec app1 ping app2

# 检查防火墙设置
sudo ufw status
```

## 📚 最佳实践

### 1. 镜像选择

```bash
# ✅ 优先选择官方镜像
docker pull nginx:alpine

# ✅ 使用特定版本标签
docker pull postgres:13.4

# ❌ 避免使用 latest 标签在生产环境
# docker pull app:latest
```

### 2. 容器命名

```bash
# ✅ 使用有意义的名称
docker run --name web-server-prod nginx

# ✅ 使用环境前缀
docker run --name prod-api-v1 api:1.0

# ❌ 避免使用随机名称
# docker run nginx
```

### 3. 资源限制

```bash
# ✅ 设置内存限制
docker run --memory=512m --name app nginx

# ✅ 设置 CPU 限制
docker run --cpus=0.5 --name app nginx

# ✅ 设置重启策略
docker run --restart=unless-stopped --name app nginx
```

### 4. 安全考虑

```bash
# ✅ 以非 root 用户运行
docker run --user 1000:1000 --name app nginx

# ✅ 只读文件系统
docker run --read-only --name app nginx

# ✅ 删除不必要的能力
docker run --cap-drop=ALL --cap-add=NET_BIND_SERVICE --name app nginx
```

## 🎯 实践练习

### 练习 1：基础操作

```bash
# 1. 拉取 nginx 镜像
docker pull nginx:alpine

# 2. 运行 nginx 容器
docker run -d --name my-nginx -p 8080:80 nginx:alpine

# 3. 访问测试
curl http://localhost:8080

# 4. 查看日志
docker logs my-nginx

# 5. 进入容器
docker exec -it my-nginx /bin/sh

# 6. 停止并删除
docker stop my-nginx
docker rm my-nginx
```

### 练习 2：多容器管理

```bash
# 1. 运行多个容器
docker run -d --name web1 -p 8081:80 nginx:alpine
docker run -d --name web2 -p 8082:80 nginx:alpine
docker run -d --name web3 -p 8083:80 nginx:alpine

# 2. 批量查看状态
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

# 3. 批量停止
docker stop web1 web2 web3

# 4. 批量删除
docker rm web1 web2 web3
```

## 📖 学习资源

### 官方文档

- 📚 [Docker Hub 官方文档](https://docs.docker.com/docker-hub/)
- 🔧 [Docker Run 参考](https://docs.docker.com/engine/reference/run/)
- 📊 [Docker CLI 命令参考](https://docs.docker.com/engine/reference/commandline/)

### 推荐镜像仓库

- 🏪 [Docker Hub](https://hub.docker.com/)
- 🔒 [Quay.io](https://quay.io/)
- ☁️ [Amazon ECR Public](https://gallery.ecr.aws/)
- 🔍 [Google Container Registry](https://gcr.io/)

## 🎯 本章小结

通过本章学习，您应该已经：

- ✅ 掌握了从 Docker Hub 搜索和拉取镜像的方法
- ✅ 学会了运行和管理 Docker 容器
- ✅ 了解了容器的生命周期管理
- ✅ 掌握了容器监控和调试技巧
- ✅ 学会了处理多平台兼容性问题
- ✅ 熟悉了 Docker 的最佳实践

**下一步：** 继续学习 [构建新的 Docker 镜像并推送到 Docker Hub](../04-Build-new-Docker-Image-and-Run-and-Push-to-DockerHub/) 章节，学习如何创建自定义镜像。
