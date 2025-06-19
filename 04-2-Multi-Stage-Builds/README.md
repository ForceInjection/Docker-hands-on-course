# 🏗️ Docker 多阶段构建

> 学习如何使用多阶段构建优化 Docker 镜像大小，提高构建效率和安全性

## 📋 本章学习目标

- 理解多阶段构建的概念和优势
- 掌握多阶段构建的语法和最佳实践
- 学会优化镜像大小和构建时间
- 了解构建缓存的使用技巧
- 掌握生产环境镜像的安全构建
- 学会调试和优化构建过程

## 🎯 什么是多阶段构建

多阶段构建允许您在单个 Dockerfile 中使用多个 `FROM` 语句，每个 `FROM` 指令可以使用不同的基础镜像，并且每个阶段都可以选择性地将文件从前一个阶段复制到当前阶段。

### 🔍 传统构建的问题

```dockerfile
# ❌ 传统单阶段构建的问题
FROM golang:1.19
WORKDIR /app
COPY . .
RUN go build -o myapp
EXPOSE 8080
CMD ["./myapp"]

# 问题：
# 1. 最终镜像包含完整的 Go 编译环境（~800MB）
# 2. 包含源代码和构建工具
# 3. 安全风险：暴露了构建过程和依赖
# 4. 镜像体积大，传输和存储成本高
```

### ✅ 多阶段构建的优势

```dockerfile
# ✅ 多阶段构建解决方案
# 第一阶段：构建阶段
FROM golang:1.19 AS builder
WORKDIR /app
COPY . .
RUN go build -o myapp

# 第二阶段：运行阶段
FROM alpine:latest
WORKDIR /app
COPY --from=builder /app/myapp .
EXPOSE 8080
CMD ["./myapp"]

# 优势：
# 1. 最终镜像只有 ~10MB
# 2. 不包含构建工具和源代码
# 3. 提高安全性
# 4. 减少攻击面
```

## 🛠️ 基础语法和概念

### 多阶段构建语法

```dockerfile
# 阶段命名
FROM <image> AS <stage-name>

# 从其他阶段复制文件
COPY --from=<stage-name> <src> <dest>
COPY --from=<stage-index> <src> <dest>

# 引用外部镜像
COPY --from=nginx:alpine /etc/nginx/nginx.conf /etc/nginx/
```

### 阶段引用方式

```dockerfile
# 方式 1：使用阶段名称（推荐）
FROM golang:1.19 AS builder
FROM alpine:latest
COPY --from=builder /app/myapp .

# 方式 2：使用阶段索引（从 0 开始）
FROM golang:1.19
FROM alpine:latest
COPY --from=0 /app/myapp .

# 方式 3：从外部镜像复制
FROM alpine:latest
COPY --from=nginx:alpine /etc/nginx/nginx.conf /etc/nginx/
```

## 📁 项目结构

让我们查看本章的示例项目：

```bash
# 查看项目文件
ls -la

# 预期文件结构：
# ├── Dockerfile              # 单阶段构建示例
# ├── Dockerfile-multi-stages # 多阶段构建示例
# ├── main.go                 # Go 应用源代码
# ├── go.mod                  # Go 模块文件
# └── README.md               # 本文档
```

## 🔧 实践示例：Go 应用多阶段构建

### 查看源代码

```bash
# 查看 Go 应用源代码
cat main.go
```

### 单阶段构建对比

首先，让我们看看传统的单阶段构建：

```dockerfile
# Dockerfile（单阶段构建）
FROM golang:1.19
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN go build -o main .
EXPOSE 8080
CMD ["./main"]
```

```bash
# 构建单阶段镜像
docker build -t single-stage-app:v1 .

# 查看镜像大小
docker images single-stage-app:v1

# 预期输出：镜像大小约 800MB+
```

### 多阶段构建实现

现在让我们使用多阶段构建：

```dockerfile
# Dockerfile-multi-stages（多阶段构建）
# 第一阶段：构建阶段
FROM golang:1.19 AS builder

# 设置工作目录
WORKDIR /app

# 复制 go mod 文件并下载依赖（利用缓存）
COPY go.mod go.sum ./
RUN go mod download

# 复制源代码
COPY . .

# 构建应用（静态链接）
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o main .

# 第二阶段：运行阶段
FROM alpine:latest

# 安装 ca-certificates（用于 HTTPS 请求）
RUN apk --no-cache add ca-certificates

# 创建非 root 用户
RUN addgroup -g 1001 -S appgroup && \
    adduser -S -D -H -u 1001 -h /app -s /sbin/nologin -G appgroup -g appgroup appuser

# 设置工作目录
WORKDIR /app

# 从构建阶段复制二进制文件
COPY --from=builder /app/main .

# 设置文件权限
RUN chown -R appuser:appgroup /app

# 切换到非 root 用户
USER appuser

# 暴露端口
EXPOSE 8080

# 启动应用
CMD ["./main"]
```

### 构建和对比

```bash
# 构建多阶段镜像
docker build -f Dockerfile-multi-stages -t stacksimplify/multi-stage-builds:v1 .

# 或者使用您的 Docker Hub ID
docker build -f Dockerfile-multi-stages -t <your-docker-hub-id>/multi-stage-builds:v1 .

# 查看构建过程
docker build -f Dockerfile-multi-stages -t stacksimplify/multi-stage-builds:v1 . --no-cache
```

### 构建过程详解

```bash
# 详细构建输出示例
$ docker build -f Dockerfile-multi-stages -t stacksimplify/multi-stage-builds:v1 .
[+] Building 45.2s (16/16) FINISHED
 => [internal] load build definition from Dockerfile-multi-stages        0.0s
 => => transferring dockerfile: 789B                                      0.0s
 => [internal] load .dockerignore                                         0.0s
 => => transferring context: 2B                                           0.0s
 => [internal] load metadata for docker.io/library/alpine:latest         1.2s
 => [internal] load metadata for docker.io/library/golang:1.19           1.3s
 => [builder 1/6] FROM docker.io/library/golang:1.19@sha256:abc123...     0.0s
 => [internal] load build context                                         0.0s
 => => transferring context: 1.23kB                                       0.0s
 => [stage-1 1/4] FROM docker.io/library/alpine:latest@sha256:def456...   0.0s
 => CACHED [builder 2/6] WORKDIR /app                                     0.0s
 => CACHED [builder 3/6] COPY go.mod go.sum ./                            0.0s
 => CACHED [builder 4/6] RUN go mod download                              0.0s
 => [builder 5/6] COPY . .                                                0.1s
 => [builder 6/6] RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o main .  42.3s
 => CACHED [stage-1 2/4] RUN apk --no-cache add ca-certificates           0.0s
 => CACHED [stage-1 3/4] RUN addgroup -g 1001 -S appgroup &&     adduser -S -D -H -u 1001 -h /app -s /sbin/nologin -G appgroup -g appgroup appuser  0.0s
 => CACHED [stage-1 4/4] WORKDIR /app                                     0.0s
 => [stage-1 5/7] COPY --from=builder /app/main .                         0.1s
 => [stage-1 6/7] RUN chown -R appuser:appgroup /app                      0.3s
 => [stage-1 7/7] USER appuser                                            0.0s
 => exporting to image                                                     0.1s
 => => exporting layers                                                    0.1s
 => => writing image sha256:ghi789...                                      0.0s
 => => naming to docker.io/stacksimplify/multi-stage-builds:v1            0.0s
```

### 镜像大小对比

```bash
# 对比镜像大小
docker images | grep -E "(single-stage-app|multi-stage-builds)"

# 预期输出对比：
# single-stage-app        v1      abc123    2 minutes ago    862MB
# multi-stage-builds      v1      def456    1 minute ago     12.3MB

# 计算节省的空间
echo "镜像大小减少了约 98.6%"
```

## 🚀 运行和测试

### 运行多阶段构建的应用

```bash
# 运行应用
docker run --name multi-stage-app -p 8080:8080 -d stacksimplify/multi-stage-builds:v1

# 检查容器状态
docker ps

# 查看容器日志
docker logs multi-stage-app

# 测试应用
curl http://localhost:8080

# 预期输出：
# Hello, World! This is a multi-stage build example.
```

### 性能和安全测试

```bash
# 检查容器内部（安全性验证）
docker exec -it multi-stage-app /bin/sh

# 在容器内部执行：
whoami          # 应该显示 appuser
ls -la          # 查看文件权限
ps aux          # 查看运行进程
which go        # 应该找不到 go 命令
which gcc       # 应该找不到 gcc 命令
exit

# 检查镜像层
docker history stacksimplify/multi-stage-builds:v1

# 检查镜像内容
docker run --rm -it stacksimplify/multi-stage-builds:v1 /bin/sh -c "ls -la /app"
```

## 🔧 高级多阶段构建技巧

### 1. 并行构建阶段

```dockerfile
# 并行构建示例
FROM node:16-alpine AS frontend-builder
WORKDIR /app/frontend
COPY frontend/package*.json ./
RUN npm install
COPY frontend/ .
RUN npm run build

FROM golang:1.19 AS backend-builder
WORKDIR /app/backend
COPY backend/go.mod backend/go.sum ./
RUN go mod download
COPY backend/ .
RUN go build -o api .

# 最终阶段：组合前后端
FROM nginx:alpine
COPY --from=frontend-builder /app/frontend/dist /usr/share/nginx/html
COPY --from=backend-builder /app/backend/api /usr/local/bin/
COPY nginx.conf /etc/nginx/nginx.conf
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
```

### 2. 构建参数和条件构建

```dockerfile
# 使用构建参数
ARG BUILD_ENV=production
ARG GO_VERSION=1.19

FROM golang:${GO_VERSION} AS builder
WORKDIR /app
COPY . .

# 根据环境进行不同的构建
RUN if [ "$BUILD_ENV" = "development" ] ; then \
        go build -gcflags="-N -l" -o app . ; \
    else \
        go build -ldflags="-s -w" -o app . ; \
    fi

FROM alpine:latest
COPY --from=builder /app/app .
CMD ["./app"]
```

### 3. 多架构构建

```dockerfile
# 支持多架构的多阶段构建
FROM --platform=$BUILDPLATFORM golang:1.19 AS builder
ARG TARGETPLATFORM
ARG BUILDPLATFORM
ARG TARGETOS
ARG TARGETARCH

WORKDIR /app
COPY . .
RUN CGO_ENABLED=0 GOOS=$TARGETOS GOARCH=$TARGETARCH go build -o app .

FROM alpine:latest
RUN apk --no-cache add ca-certificates
COPY --from=builder /app/app .
CMD ["./app"]
```

### 4. 缓存优化

```dockerfile
# 优化构建缓存
FROM golang:1.19 AS builder
WORKDIR /app

# 先复制依赖文件（利用 Docker 层缓存）
COPY go.mod go.sum ./
RUN go mod download

# 再复制源代码（源代码变化不会影响依赖缓存）
COPY . .
RUN go build -o app .

FROM alpine:latest
COPY --from=builder /app/app .
CMD ["./app"]
```

## 🎯 实际应用场景

### 1. Node.js 应用

```dockerfile
# Node.js 多阶段构建
FROM node:16-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production

FROM node:16-alpine AS runtime
WORKDIR /app
COPY --from=builder /app/node_modules ./node_modules
COPY . .
EXPOSE 3000
CMD ["node", "index.js"]
```

### 2. Python 应用

```dockerfile
# Python 多阶段构建
FROM python:3.9-slim AS builder
WORKDIR /app
COPY requirements.txt .
RUN pip install --user -r requirements.txt

FROM python:3.9-slim AS runtime
WORKDIR /app
COPY --from=builder /root/.local /root/.local
COPY . .
ENV PATH=/root/.local/bin:$PATH
CMD ["python", "app.py"]
```

### 3. Java 应用

```dockerfile
# Java 多阶段构建
FROM maven:3.8-openjdk-11 AS builder
WORKDIR /app
COPY pom.xml .
RUN mvn dependency:go-offline
COPY src ./src
RUN mvn clean package -DskipTests

FROM openjdk:11-jre-slim
WORKDIR /app
COPY --from=builder /app/target/*.jar app.jar
EXPOSE 8080
CMD ["java", "-jar", "app.jar"]
```

## 🔍 调试和优化

### 构建特定阶段

```bash
# 只构建到特定阶段（用于调试）
docker build --target builder -t debug-builder .

# 运行构建阶段进行调试
docker run -it --rm debug-builder /bin/bash

# 在构建阶段内部检查
ls -la
go version
which go
```

### 分析构建缓存

```bash
# 查看构建缓存使用情况
docker system df

# 清理构建缓存
docker builder prune

# 查看详细的构建过程
docker build --progress=plain -f Dockerfile-multi-stages -t test .
```

### 镜像分析工具

```bash
# 使用 dive 分析镜像层
# 安装 dive（如果未安装）
brew install dive  # macOS
# 或
sudo apt-get install dive  # Ubuntu

# 分析镜像
dive stacksimplify/multi-stage-builds:v1

# 使用 docker history 查看层信息
docker history stacksimplify/multi-stage-builds:v1
```

## 📊 性能对比测试

### 构建时间对比

```bash
# 测试单阶段构建时间
time docker build -t single-stage-test .

# 测试多阶段构建时间
time docker build -f Dockerfile-multi-stages -t multi-stage-test .

# 测试缓存效果（第二次构建）
time docker build -f Dockerfile-multi-stages -t multi-stage-test-2 .
```

### 镜像传输测试

```bash
# 模拟镜像推送时间（基于大小估算）
docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}" | grep -E "(single-stage|multi-stage)"

# 计算传输时间差异（假设网络速度 10MB/s）
echo "单阶段镜像传输时间: ~86 秒"
echo "多阶段镜像传输时间: ~1.2 秒"
echo "传输时间节省: ~98.6%"
```

## 🛡️ 安全最佳实践

### 1. 最小化攻击面

```dockerfile
# ✅ 好的实践
FROM golang:1.19 AS builder
# ... 构建过程 ...

# 使用 distroless 或 scratch 镜像
FROM gcr.io/distroless/static:nonroot
COPY --from=builder /app/myapp /myapp
USER nonroot:nonroot
ENTRYPOINT ["/myapp"]
```

### 2. 避免敏感信息泄露

```dockerfile
# ❌ 避免在最终镜像中包含
# - 源代码
# - 构建工具
# - 开发依赖
# - 密钥和证书
# - 调试信息

# ✅ 正确的做法
FROM builder AS secrets
RUN --mount=type=secret,id=api_key \
    echo "Using secret without copying to layer"

FROM alpine:latest
COPY --from=builder /app/binary /app/
# 不复制敏感文件
```

### 3. 使用非 root 用户

```dockerfile
FROM alpine:latest
RUN addgroup -g 1001 -S appgroup && \
    adduser -S -D -H -u 1001 -h /app -s /sbin/nologin -G appgroup -g appgroup appuser
USER appuser
COPY --from=builder --chown=appuser:appgroup /app/binary /app/
```

## 📚 最佳实践总结

### ✅ 推荐做法

1. **使用具体的基础镜像标签**

   ```dockerfile
   FROM golang:1.19-alpine  # ✅ 具体版本
   FROM golang:latest       # ❌ 避免使用 latest
   ```

2. **优化层缓存**

   ```dockerfile
   # ✅ 先复制依赖文件
   COPY go.mod go.sum ./
   RUN go mod download
   COPY . .  # 源代码变化不影响依赖缓存
   ```

3. **使用 .dockerignore**

   ```text
   .git
   .gitignore
   README.md
   Dockerfile*
   .dockerignore
   node_modules
   *.log
   ```

4. **合理命名构建阶段**

   ```dockerfile
   FROM golang:1.19 AS builder      # ✅ 描述性名称
   FROM alpine:latest AS runtime    # ✅ 清晰的用途
   ```

### ❌ 避免的做法

1. **在最终镜像中包含构建工具**
2. **使用过大的基础镜像**
3. **忽略安全扫描**
4. **不使用构建缓存优化**

## 🎯 实践练习

### 练习 1：优化现有应用

```bash
# 1. 找一个现有的单阶段 Dockerfile
# 2. 将其转换为多阶段构建
# 3. 对比镜像大小和安全性
# 4. 测试功能是否正常
```

### 练习 2：多语言应用

```bash
# 创建一个包含前端（React）和后端（Go）的应用
# 使用多阶段构建分别构建前后端
# 最终组合到一个 Nginx 镜像中
```

### 练习 3：构建优化

```bash
# 1. 分析构建时间
# 2. 优化 Dockerfile 层缓存
# 3. 使用 BuildKit 功能
# 4. 对比优化前后的效果
```

## 📖 学习资源

### 官方文档

- 📚 [多阶段构建官方文档](https://docs.docker.com/develop/dev-best-practices/)
- 🏗️ [Dockerfile 最佳实践](https://docs.docker.com/develop/dev-best-practices/)
- 🔧 [BuildKit 功能](https://docs.docker.com/buildx/working-with-buildx/)

### 工具和资源

- 🔍 [Dive - 镜像分析工具](https://github.com/wagoodman/dive)
- 🛡️ [Docker Bench Security](https://github.com/docker/docker-bench-security)
- 📊 [Container Structure Tests](https://github.com/GoogleContainerTools/container-structure-test)

### 进阶阅读

- 🚀 [生产环境 Docker 最佳实践](https://docs.docker.com/config/containers/)
- 🔒 [容器安全指南](https://docs.docker.com/engine/security/)
- 📦 [镜像优化技巧](https://docs.docker.com/develop/dev-best-practices/)

## 🎯 本章小结

通过本章学习，您应该已经：

- ✅ 理解了多阶段构建的概念和优势
- ✅ 掌握了多阶段构建的语法和技巧
- ✅ 学会了优化镜像大小和构建效率
- ✅ 了解了安全构建的最佳实践
- ✅ 掌握了调试和优化构建过程的方法
- ✅ 熟悉了不同语言和框架的多阶段构建模式

**关键收获：**

- 🎯 镜像大小可以减少 90%+
- 🛡️ 显著提高安全性
- ⚡ 优化构建和部署效率
- 🔧 掌握生产级 Docker 构建技能

**下一步：** 继续学习 [多平台构建](../04-3-Multi-Platform-Builds/) 章节，学习如何构建支持多种架构的镜像。
