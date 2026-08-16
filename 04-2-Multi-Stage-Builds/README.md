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
FROM golang:1.23
COPY <<EOF ./main.go
# ... Go 源码通过 heredoc 语法内嵌，见下文「查看源代码」 ...
EOF
RUN go build -o /bin/hello ./main.go
CMD ["/bin/hello"]

# 问题：
# 1. 最终镜像包含完整的 Go 编译环境（实测 1.27GB）
# 2. 包含源代码和构建工具
# 3. 安全风险：暴露了构建过程和依赖
# 4. 镜像体积大，传输和存储成本高
```

### ✅ 多阶段构建的优势

```dockerfile
# ✅ 多阶段构建解决方案
# 第一阶段：构建阶段
FROM golang:1.23 AS build
WORKDIR /src
COPY <<EOF /src/main.go
# ... Go 源码通过 heredoc 语法内嵌，见下文「查看源代码」 ...
EOF
RUN go build -o /bin/hello ./main.go

# 第二阶段：运行阶段
FROM scratch
COPY --from=build /bin/hello /bin/hello
CMD ["/bin/hello"]

# 优势：
# 1. 最终镜像只有 3.41MB（实测）
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
FROM golang:1.23 AS builder
FROM alpine:latest
COPY --from=builder /app/myapp .

# 方式 2：使用阶段索引（从 0 开始）
FROM golang:1.23
FROM alpine:latest
COPY --from=0 /app/myapp .

# 方式 3：从外部镜像复制
FROM alpine:latest
COPY --from=nginx:alpine /etc/nginx/nginx.conf /etc/nginx/
```

## 📁 项目结构

本章示例项目非常精简：

```bash
# 查看项目文件
ls -la

# 实际文件结构：
# ├── Dockerfile                # 单阶段构建示例（用于对比）
# ├── Dockerfile-multi-stages   # 多阶段构建示例
# ├── docker-multi-stage-build-cn.md  # 延伸阅读：多阶段构建详解文章
# └── README.md                 # 本文档
```

> 💡 **注意**：示例的 Go 源码通过 BuildKit 的 heredoc 语法（`COPY <<EOF`）直接内嵌在 Dockerfile 中，因此不需要单独的 `main.go` / `go.mod` 文件。这也是 heredoc 语法的教学演示点。

## 🔧 实践示例：Go 应用多阶段构建

### 查看源代码

本章的 Go 源码通过 heredoc 语法内嵌在两个 Dockerfile 中，内容完全相同：

```dockerfile
# 两个 Dockerfile 中共有的源码片段（heredoc 内嵌）
COPY <<EOF ./main.go
package main

import "fmt"

func main() {
  fmt.Println("hello, world")
}
EOF
```

这是一个刻意最小化的 "hello, world" 程序——让关注点完全放在「镜像的构建方式」上。

### 单阶段构建对比

首先构建传统的单阶段镜像，本章的 `Dockerfile` 就是单阶段构建：

```dockerfile
# Dockerfile（单阶段构建，本章实际文件）
# syntax=docker/dockerfile:1
FROM golang:1.23
WORKDIR /src
COPY <<EOF ./main.go
package main

import "fmt"

func main() {
  fmt.Println("hello, world")
}
EOF
RUN go build -o /bin/hello ./main.go
CMD ["/bin/hello"]
```

```bash
# 构建单阶段镜像
docker build -f Dockerfile -t single-stage-app:v1 .

# 查看镜像大小
docker images single-stage-app:v1

# ✅ 实测输出（Apple Silicon + colima）：
# REPOSITORY         TAG       IMAGE ID       CREATED          SIZE
# single-stage-app   v1        xxx            2 minutes ago    1.27GB
```

### 多阶段构建实现

现在使用多阶段构建。本章的 `Dockerfile-multi-stages` 把「构建」和「运行」拆成两个阶段：

```dockerfile
# Dockerfile-multi-stages（多阶段构建，本章实际文件）
# syntax=docker/dockerfile:1
# 第一阶段：构建阶段
FROM golang:1.23 AS build
WORKDIR /src

# 源码通过 heredoc 语法内嵌，无需独立的 .go 文件
COPY <<EOF /src/main.go
package main

import "fmt"

func main() {
  fmt.Println("hello, world")
}
EOF

# 编译为二进制
RUN go build -o /bin/hello ./main.go

# 第二阶段：运行阶段——scratch 空镜像，只保留二进制
FROM scratch
COPY --from=build /bin/hello /bin/hello
CMD ["/bin/hello"]
```

> 💡 **heredoc 语法**：`COPY <<EOF` 是 BuildKit 支持的 heredoc 写法，可以把小段文件内容直接内嵌在 Dockerfile 中，免去单独创建源文件。该语法需要 BuildKit（`docker buildx`）支持，现代 Docker 版本默认启用；若 `docker build` 提示 legacy builder 或 heredoc 语法错误，请先安装 buildx 插件（参见[多平台构建](../04-3-Multi-Platform-Builds/)章节的安装方法）。

### 构建和对比

```bash
# 构建多阶段镜像
docker build -f Dockerfile-multi-stages -t multi-stage-builds:v1 .

# 无缓存重新构建（观察每一步的执行过程）
docker build --no-cache -f Dockerfile-multi-stages -t multi-stage-builds:v1 .
```

> ⚠️ **注意**：`--no-cache` 等构建选项必须放在构建上下文（`.`）之前。

### 构建过程详解

无缓存构建的详细输出（✅ 实测，Apple Silicon + colima + buildx）：

```text
$ docker build --no-cache -f Dockerfile-multi-stages -t multi-stage-builds:v1 .
#0 building with "colima" instance using docker driver
#1 [internal] load build definition from Dockerfile-multi-stages
#1 transferring dockerfile: 331B done
#1 DONE 0.0s
#4 [internal] load metadata for docker.io/library/golang:1.23
#4 DONE 0.9s
#6 [build 1/4] FROM docker.io/library/golang:1.23@sha256:60deed... done
#8 [build 2/4] WORKDIR /src
#9 [build 3/4] COPY <<EOF /src/main.go
#9 DONE 0.0s
#10 [build 4/4] RUN go build -o /bin/hello ./main.go
#10 DONE 3.0s
#11 [stage-1 1/1] COPY --from=build /bin/hello /bin/hello
#12 exporting to image
#12 exporting layers 0.1s done
#12 naming to docker.io/library/multi-stage-builds:v1 done
#12 unpacking to docker.io/library/multi-stage-builds:v1 0.0s done
```

关键观察：

- `[build x/4]` 是第一阶段（构建）的 4 个步骤，`[stage-1 1/1]` 是第二阶段（运行），两个阶段各用各的基础镜像
- heredoc 步骤在输出中显示为 `COPY <<EOF /src/main.go`
- 第二阶段只有 1 步：把编译产物复制到 `scratch` 空镜像

### 镜像大小对比

```bash
# 对比镜像大小
docker images | grep -E "(single-stage-app|multi-stage-builds)"

# ✅ 实测输出对比（Apple Silicon + colima）：
# single-stage-app        v1      xxx    2 minutes ago    1.27GB
# multi-stage-builds      v1      xxx    1 minute ago     3.41MB

# 计算节省的空间
echo "镜像大小减少了约 99.7%"
```

## 🚀 运行和测试

### 运行多阶段构建的应用

```bash
# 运行应用（scratch 镜像只有一个静态二进制，无需任何运行时依赖）
docker run --rm multi-stage-builds:v1

# ✅ 实测输出：
# hello, world

# 单阶段镜像运行结果相同，但携带了整套 Go 工具链
docker run --rm single-stage-app:v1

# ✅ 实测输出：
# hello, world
```

### 安全性验证：scratch 镜像里到底有什么

`scratch` 镜像没有 shell，无法用 `docker exec` 进入，改用导出方式查看文件系统：

```bash
# 导出多阶段镜像的文件系统（✅ 实测输出）
cid=$(docker create multi-stage-builds:v1)
docker export $cid | tar -t
docker rm $cid

# bin/hello  ← 整个镜像只有一个可执行文件！
# etc/hostname、etc/hosts、etc/resolv.conf 为 Docker 运行时注入，不属于镜像

# 查看镜像层历史：整个镜像只有两层（✅ 实测输出）
docker history multi-stage-builds:v1

# IMAGE      CREATED      CREATED BY                     SIZE
# <latest>   ...          CMD ["/bin/hello"]             0B
# <latest>   ...          COPY /bin/hello /bin/hello     2.17MB
```

作为对比，查看单阶段镜像的层历史：

```bash
docker history single-stage-app:v1

# ✅ 实测输出（节选）——Go 工具链层约 279MB，编译层约 34.4MB，
# 这些在生产镜像中全部是多余的攻击面：
# COPY /target/ / # buildkit                           279MB
# RUN /bin/sh -c go build -o /bin/hello ./main...      34.4MB
```

> 💡 如需进入构建环境调试（例如检查 `go version`），scratch 运行阶段无法满足，可用 `docker build --target build` 构建出第一阶段的调试镜像，详见下文「构建特定阶段」。

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

FROM golang:1.23 AS backend-builder
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
FROM --platform=$BUILDPLATFORM golang:1.23 AS builder
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
FROM golang:1.23 AS builder
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
# 注意：--target 使用阶段名称，本章多阶段 Dockerfile 中为 build
docker build -f Dockerfile-multi-stages --target build -t debug-build .

# 运行构建阶段进行调试
docker run -it --rm debug-build /bin/bash

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
dive multi-stage-builds:v1

# 使用 docker history 查看层信息
docker history multi-stage-builds:v1
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

# 计算传输时间差异（假设网络速度 10MB/s，基于实测大小 1.27GB / 3.41MB）
echo "单阶段镜像传输时间: ~127 秒"
echo "多阶段镜像传输时间: ~0.34 秒"
echo "传输时间节省: ~99.7%"
```

## 🛡️ 安全最佳实践

### 1. 最小化攻击面

```dockerfile
# ✅ 好的实践
FROM golang:1.23 AS builder
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
   FROM golang:1.23-alpine  # ✅ 具体版本
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
   FROM golang:1.23 AS builder      # ✅ 描述性名称
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

- 🎯 镜像大小可以减少 99%+（实测 1.27GB → 3.41MB）
- 🛡️ 显著提高安全性
- ⚡ 优化构建和部署效率
- 🔧 掌握生产级 Docker 构建技能

**下一步：** 继续学习 [多平台构建](../04-3-Multi-Platform-Builds/) 章节，学习如何构建支持多种架构的镜像。
