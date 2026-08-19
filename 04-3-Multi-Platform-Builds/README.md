# 🛠️ Docker 多平台镜像构建

> 学习如何使用 Docker Buildx 与 tonistiigi/xx 交叉编译工具，一套 Dockerfile 构建多种 CPU 架构的镜像

## 📋 本章学习目标

- 理解多平台构建的适用场景（Apple Silicon、ARM 服务器、边缘设备）
- 掌握 Docker Buildx 插件的安装与配置
- 理解 QEMU 模拟执行与原生交叉编译两种方案的差异
- 掌握 tonistiigi/xx 交叉编译工具的使用方法
- 学会在本地构建指定平台镜像并验证（`--load`）
- 学会构建多平台镜像并推送镜像仓库（`--push`）

## 🌍 为什么需要多平台构建

2020 年 Apple 发布 M1 芯片后，ARM 架构迅速进入主流：云服务器（AWS Graviton、阿里云倚天）、开发机（Apple Silicon Mac）、边缘设备与树莓派都采用 ARM 架构。而传统镜像分发只面向单一架构，同一应用往往需要维护多份构建产物。

多平台构建可以**用同一套 Dockerfile 与源码，一次构建出多架构镜像**（如 `linux/amd64` + `linux/arm64`），推送到镜像仓库后，用户在不同平台上 `docker pull` 时自动获取对应架构的镜像。

### 🔄 两种构建方案对比

| 方案 | 原理 | 速度 | 适用场景 |
| --- | --- | --- | --- |
| QEMU 模拟（默认） | 在模拟器中执行目标架构指令 | 慢（模拟执行） | 无法交叉编译的构建，快速尝鲜 |
| 原生交叉编译（xx 工具） | 编译器直接生成目标架构二进制 | 快（接近本机构建） | Go、Rust、C/C++ 等主流语言，本章采用 |

交叉编译的通用原理：`docker buildx build --platform` 会自动注入两个全局 ARG —— `TARGETPLATFORM`（目标平台）与 `BUILDPLATFORM`（构建机平台）。让构建阶段始终运行在 `$BUILDPLATFORM` 上、再通过交叉编译器产出 `$TARGETPLATFORM` 的二进制，就可以避免模拟执行。

## 🛠️ 环境准备

### 安装 Docker Buildx 插件

Buildx 是 Docker 官方的构建插件，支持多平台构建、缓存导出等高级特性。

- **Docker Desktop**：已内置 Buildx，无需额外安装
- **macOS / Windows 其他运行时（如 Colima）**：将插件二进制放到 `~/.docker/cli-plugins/` 即可
- **Linux**：使用包管理器安装 `docker-buildx-plugin`，或手动安装：

```bash
mkdir -p ~/.docker/cli-plugins/
curl -SL https://github.com/docker/buildx/releases/latest/download/docker-buildx-linux-amd64 -o ~/.docker/cli-plugins/docker-buildx
chmod +x ~/.docker/cli-plugins/docker-buildx
```

> 💡 `docker buildx` 各平台最新版本与安装方式见 [buildx 官方仓库](https://github.com/docker/buildx)。安装后可用 `docker buildx version` 验证。

### 📁 项目结构

```
04-3-Multi-Platform-Builds/
├── README.md                    # 本章文档（本文件）
├── xx-tool.md                   # tonistiigi/xx 工具详解（交叉编译命令速查）
├── Dockerfile-multi-platform    # 多平台构建示例 Dockerfile
└── app/
    └── main.go                  # Go 示例程序（输出 hello, world）
```

## 🔧 Dockerfile 详解

本示例由三个阶段组成：xx 工具阶段、构建阶段、运行阶段。

```dockerfile
FROM --platform=$BUILDPLATFORM tonistiigi/xx AS xx
# 第一阶段：构建阶段
FROM --platform=$BUILDPLATFORM golang:1.23 AS builder
RUN DEBIAN_FRONTEND=noninteractive apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get -y install build-essential && \
    DEBIAN_FRONTEND=noninteractive apt-get -y clean

COPY --from=tonistiigi/xx / /
ADD app /app
ARG TARGETPLATFORM
RUN xx-apt install -y libc6-dev gcc
ENV CGO_ENABLED=1
WORKDIR /app

RUN echo "Building for platform: $TARGETPLATFORM"

# 设置环境变量以指定构建平台架构
RUN xx-go --wrap && xx-go build -o /bin/hello ./main.go && xx-verify /bin/hello

# 第二阶段：运行阶段
FROM debian:buster-slim

# 复制二进制文件到运行镜像中
COPY --from=builder /bin/hello /bin/hello

# 设置工作目录
WORKDIR /app

# 设置程序入口
CMD ["/bin/hello"]
```

要点解析：

| 阶段 / 指令 | 作用 |
| --- | --- |
| `FROM --platform=$BUILDPLATFORM` | 该阶段始终在构建机原生架构上运行，避免模拟执行 |
| `FROM tonistiigi/xx AS xx` + `COPY --from=tonistiigi/xx / /` | 引入 xx 工具（提供 `xx-go`、`xx-apt`、`xx-verify` 等命令） |
| `ARG TARGETPLATFORM` | 读取 buildx 注入的目标平台变量（如 `linux/arm64`） |
| `xx-apt install -y libc6-dev gcc` | 自动安装**目标架构**的 C 库与编译器依赖 |
| `CGO_ENABLED=1` | 启用 CGo（本项目虽未用 C 代码，但展示真实项目交叉编译的常见配置） |
| `xx-go --wrap` | 让 go 命令自动携带目标平台的环境变量（GOOS/GOARCH 等） |
| `xx-verify /bin/hello` | 校验产物确为目标架构，防止误输出本机架构二进制 |

> 📖 `xx` 的全部命令（xx-info / xx-apk / xx-clang / xx-cargo 等）详见 [xx-tool.md](xx-tool.md)。

## 🚀 实操一：本地构建 arm64 镜像（实测）

在构建机（本教程实测为 Apple Silicon Mac）上构建 arm64 镜像并加载到本地：

```bash
docker buildx build -f Dockerfile-multi-platform --platform linux/arm64 --tag multi-platform:latest --load .
```

```
[+] Building 48.2s (19/19) FINISHED                                                                                                                                                                    docker:default
 => [internal] load build definition from Dockerfile-multi-platform                                                                                                                                              0.0s
 => => transferring dockerfile: 937B                                                                                                                                                                             0.0s
 => [internal] load .dockerignore                                                                                                                                                                                0.0s
 => => transferring context: 2B                                                                                                                                                                                  0.0s
 => [internal] load metadata for docker.io/library/golang:1.23                                                                                                                                                  31.9s
 => [internal] load metadata for docker.io/tonistiigi/xx:latest                                                                                                                                                 32.2s
 => [internal] load metadata for docker.io/library/debian:buster-slim                                                                                                                                           31.8s
 => [builder 1/8] FROM docker.io/library/golang:1.23@sha256:2fe82a3f3e006b4f2a316c6a21f62b66e1330ae211d039bb8d1128e12ed57bf1                                                                                     0.0s
 => FROM docker.io/tonistiigi/xx@sha256:0c6a569797744e45955f39d4f7538ac344bfb7ebf0a54006a0a4297b153ccf0f                                                                                                         0.0s
 => [stage-2 1/3] FROM docker.io/library/debian:buster-slim@sha256:bb3dc79fddbca7e8903248ab916bb775c96ec61014b3d02b4f06043b604726dc                                                                              0.0s
 => [internal] load build context                                                                                                                                                                                0.0s
 => => transferring context: 55B                                                                                                                                                                                 0.0s
 => CACHED [builder 2/8] RUN DEBIAN_FRONTEND=noninteractive apt-get update &&     DEBIAN_FRONTEND=noninteractive apt-get -y install build-essential &&     DEBIAN_FRONTEND=noninteractive apt-get -y clean                                                                         0.0s
 => CACHED [builder 3/8] COPY --from=tonistiigi/xx / /                                                                                                                                                           0.0s
 => CACHED [builder 4/8] ADD app /app                                                                                                                                                                            0.0s
 => CACHED [builder 5/8] RUN xx-apt install -y libc6-dev gcc                                                                                                                                                     0.0s
 => CACHED [builder 6/8] WORKDIR /app                                                                                                                                                                            0.0s
 => CACHED [builder 7/8] RUN echo "Building for platform: linux/arm64"                                                                                                                                           0.0s
 => [builder 8/8] RUN xx-go --wrap && xx-go build -o /bin/hello ./main.go && xx-verify /bin/hello                                                                                                               15.9s
 => CACHED [stage-2 2/3] COPY --from=builder /bin/hello /bin/hello                                                                                                                                               0.0s
 => CACHED [stage-2 3/3] WORKDIR /app                                                                                                                                                                            0.0s
 => exporting to image                                                                                                                                                                                           0.0s
 => => exporting layers                                                                                                                                                                                          0.0s
 => => writing image sha256:f62af6260d60063ddad7ed6a25fab945e769372ffc0047881a56b9c52480a987                                                                                                                     0.0s
 => => naming to docker.io/library/multi-platform:latest                                                                                                                                                         0.0s
```

关键观察：

- 构建阶段全部运行在构建机原生架构上（`builder` 步骤），只有最后的 `xx-go build` 真正执行交叉编译（15.9s，接近本机构建速度）
- 二次构建时依赖步骤全部命中缓存（`CACHED`），仅重新编译源码变更部分
- 产物 `multi-platform:latest` 大小约 **66.3MB**

## 📤 实操二：多平台构建并推送 Docker Hub

同时构建 amd64 与 arm64 两个架构，并直接推送到镜像仓库：

```bash
docker buildx build -f Dockerfile-multi-platform --platform linux/amd64,linux/arm64 --tag grissomsh/go-multi-platform:latest --push .
```

```
[+] Building 53.1s (35/35) FINISHED                                                                                                                                                    docker-container:multi-builder
 => [internal] load build definition from Dockerfile-multi-platform                                                                                                                                              0.0s
 => => transferring dockerfile: 936B                                                                                                                                                                             0.0s
 => [linux/amd64 internal] load metadata for docker.io/tonistiigi/xx:latest                                                                                                                                      4.5s
 => [linux/arm64 internal] load metadata for docker.io/library/golang:1.23                                                                                                                                       2.6s
 => [linux/arm64 internal] load metadata for docker.io/library/debian:buster-slim                                                                                                                                2.6s
 => [linux/arm64 internal] load metadata for docker.io/tonistiigi/xx:latest                                                                                                                                      2.6s
 => [linux/amd64 internal] load metadata for docker.io/library/debian:buster-slim                                                                                                                                2.6s
 => [auth] library/debian:pull token for registry-1.docker.io                                                                                                                                                    0.0s
 => [auth] tonistiigi/xx:pull token for registry-1.docker.io                                                                                                                                                     0.0s
 => [auth] library/golang:pull token for registry-1.docker.io                                                                                                                                                    0.0s
 => [internal] load .dockerignore                                                                                                                                                                                0.0s
 => => transferring context: 2B                                                                                                                                                                                  0.0s
 => [linux/arm64 builder 1/8] FROM docker.io/library/golang:1.23@sha256:2fe82a3f3e006b4f2a316c6a21f62b66e1330ae211d039bb8d1128e12ed57bf1                                                                         0.0s
 => [linux/arm64 builder 8/8] RUN xx-go --wrap && xx-go build -o /bin/hello ./main.go && xx-verify /bin/hello                                                                                                    9.1s
 => [linux/arm64->amd64 builder 8/8] RUN xx-go --wrap && xx-go build -o /bin/hello ./main.go && xx-verify /bin/hello                                                                                             0.0s
 ...（中间依赖步骤全部命中 CACHED，省略）...
 => exporting to image                                                                                                                                                                                          39.2s
 => => exporting layers                                                                                                                                                                                          0.0s
 => => exporting manifest sha256:805aa79abaa65b6402417d3b813df511feac6b0bcb7d255137b693188390c766                                                                                                                0.0s
 => => exporting config sha256:d9fb9042cebf4d51ee5bd2e0851bb6f5f3a8650b4b80c1c6ffb34371c85524d0                                                                                                                  0.0s
 => => exporting attestation manifest sha256:648815394b3e069b87e9d023c5df54d5db532c56fd3b98dcd89767c56a4daf64                                                                                                    0.0s
 => => exporting manifest sha256:3d7a67a432187e1d967055fb3057a316f79274c22f8747aa05f06f62d3b2c17f                                                                                                                0.0s
 => => exporting config sha256:b87c33ba6075fd10784bfe1cc064fb5894db71927ceb8be73bed1d47182af810                                                                                                                  0.0s
 => => exporting attestation manifest sha256:e68020dd9906fdc01026341fc3ea1ad2acb04458d153c69c776a1a1037c9d5cb                                                                                                    0.0s
 => => exporting manifest list sha256:34ba25bbc06506f35f6ebbf7063f0f1c1107834c12aa554703cb62bb771dc57f                                                                                                           0.0s
 => => pushing layers                                                                                                                                                                                           33.7s
 => => pushing manifest for docker.io/grissomsh/go-multi-platform:latest@sha256:34ba25bbc06506f35f6ebbf7063f0f1c1107834c12aa554703cb62bb771dc57f                                                                  5.5s
 => [auth] grissomsh/go-multi-platform:pull,push token for registry-1.docker.io
```

关键观察：

- 首次构建会同时启动两个架构的构建任务（`linux/arm64` 与 `linux/amd64`），交叉编译依赖 `xx` 工具，**无需 QEMU 模拟**
- 推送到仓库的是 **manifest list**（多架构索引），一个 tag 同时指向 amd64 与 arm64 两份镜像
- 推送前需先 `docker login`；成功后可在 [Docker Hub 仓库页面](https://hub.docker.com/repository/docker/grissomsh/go-multi-platform/general) 查看镜像信息

## ✅ 验证构建结果

**1. 检查镜像架构（实测）**

```bash
docker images | grep multi
docker inspect f62af6260d60 | grep -i arch
```

```
multi-platform                        latest    f62af6260d60   2 hours ago   66.3MB
        "Architecture": "arm64",
```

**2. 架构不匹配时报错**

如果在 x86_64 主机上运行 arm64 镜像（或反之），会报 `exec format error`：

```bash
docker run -it --platform linux/arm64  multi-platform /bin/bash
exec /bin/bash: exec format error
```

> 💡 该报错是交叉编译最常见的排查点：`xx-verify` 在构建阶段就校验产物架构，可在第一时间发现此类问题。

## 📖 参考文档

- [xx-tool.md](xx-tool.md) — tonistiigi/xx 工具详解（本章配套）
- [Multi-platform builds（Docker 官方文档）](https://docs.docker.com/build/building/multi-platform/)
- [Faster Multi-Platform Builds: Dockerfile Cross-Compilation Guide](https://www.docker.com/blog/faster-multi-platform-builds-dockerfile-cross-compilation-guide/)
- [How to build docker images on Apple M-series](https://www.izumanetworks.com/blog/build-docker-on-apple-m/)

## 💡 实践建议

- **先本地验证再推送**：先在开发机上用 `--load` 构建目标平台镜像并 `docker run` 测试，通过后再用 `--push` 发布
- **善用缓存**：`ARG TARGETPLATFORM` 之后的依赖安装步骤在换平台构建时会重建，把耗时的依赖安装放在不依赖平台变量的位置可提高缓存命中率
- **CGo 项目注意**：交叉编译 CGo 时务必显式设置 `CGO_ENABLED=1`，否则 Go 默认禁用 CGo，可能与本地构建行为不一致（详见 [xx-tool.md](xx-tool.md) 的 Go/Cgo 一节）
- **验证产物架构**：养成使用 `xx-verify` 的习惯，避免"构建成功但运行时 exec format error"
- **团队协作**：多平台镜像只需一个 tag，在不同架构的机器上 `docker pull` 自动获取对应架构，可统一 CI/CD 产物
