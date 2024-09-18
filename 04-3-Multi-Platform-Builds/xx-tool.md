# xx - Dockerfile 交叉编译助手

[`tonistiigi/xx` 工具官网地址](https://github.com/tonistiigi/xx)

`xx` 提供了工具来支持从 `Dockerfile` 进行交叉编译，这些 `Dockerfile` 能理解从 `docker build` 或 `docker buildx build` 传递进来的 `--platform` 标志。这些助手允许你将任何架构构建成任何由编译器支持的架构，并且具有原生性能的多平台镜像。将 `xx` 添加到 `Dockerfile` 中应该只需要最小的更新，并且不需要为特定架构定制条件。

## Dockerfile 交叉编译入门

通过使用多阶段构建和定义某些阶段始终在构建器使用的原生架构上运行，并执行交叉编译编译器，可以在 `Dockerfile` 中实现交叉编译。默认情况下，以 `FROM` 关键字开始的 `Dockerfile` 阶段默认为目标架构，但可以通过 `FROM --platform` 标志覆盖。使用在全局范围内的自动平台 `ARGs`，可以将交叉编译器阶段的平台设置为 `$BUILDPLATFORM`，而 `$TARGETPLATFORM` 的值可以通过环境变量传递给编译器。

编译完成后，可以将结果资产复制到另一个阶段，该阶段将成为构建的结果。通常，这个阶段不使用 `FROM --platform`，以便每个阶段都基于预期的目标架构。

```dockerfile
FROM --platform=$BUILDPLATFORM alpine AS xbuild
ARG TARGETPLATFORM
RUN ./compile --target=$TARGETPLATFORM -o /out/myapp

FROM alpine
COPY --from=xbuild /out/myapp /bin
```

## 安装

```dockerfile
FROM --platform=$BUILDPLATFORM tonistiigi/xx AS xx

FROM --platform=$BUILDPLATFORM alpine

将 xx 脚本复制到你的构建阶段

COPY --from=xx / /

导出 TARGETPLATFORM（或其他 TARGET*）

ARG TARGETPLATFORM

你现在可以调用 xx-* 命令

RUN xx-info env
```

## 支持的目标平台

`xx` 支持从 `Linux amd64`、`arm64`、`arm/v7`、`s390x`、`ppc64le` 和 `386` 以及 `Alpine`、`Debian` 和 `Ubuntu` 构建。对于 `Go` 和 `Rust` 构建，以及提供 `Risc-V` 包的较新发行版（如 `alpine:edge` 或 `debian:sid`），支持 `Risc-V`。当提供外部 `SDK` 镜像时，支持 `MacOS` 目标的 `C/C++/CGo/Rust` 构建。

## xx-info 命令 - 关于构建上下文的信息

`xx-info` 命令返回有关当前构建上下文的标准化信息。它允许你获取有关你的构建目标和配置的各种信息，并避免在你的代码中从一种格式转换为另一种格式的需要。不附加任何额外参数调用 `xx-info` 将调用 `xx-info triple`。

### 解析当前目标平台

- `xx-info os` - 打印 `TARGETPLATFORM` 的操作系统组件（linux, darwin, windows, wasi）
- `xx-info arch` - `TARGETPLATFORM` 的架构组件
- `xx-info variant` - 如果架构是 `arm`，则打印 `TARGETPLATFORM` 的变体组件（例如 v7）

### 架构格式

这些命令返回特定工具使用的架构名称，以避免在你的代码中进行转换和跟踪异常。例如，`arm64` 仓库在 `Alpine` 中称为 `aarch64`，但在 `Debian` 中称为 `arm64`。`uname -m` 在 `Linux` 中返回 `aarch64`，但在 `Darwin` 中返回 `arm64` 等。

- `xx-info march` - 预期与 `uname -m` 值匹配的目标机器架构
- `xx-info alpine-arch` - 针对 Alpine 软件包仓库的目标架构
- `xx-info debian-arch` - 针对 Debian 软件包仓库的目标架构
- `xx-info rhel-arch` - 针对 RPM 软件包仓库的目标架构
- `xx-info pkg-arch` - 根据上下文是 alpine-arch、debian-arch 或 rhel-arch

### 目标三元组

目标三元组是各种基于 gcc 和 llvm 的编译器所接受的目标格式。

- `xx-info triple` - 以 `arch[-vendor]-os-abi` 形式的目标三元组。此命令是默认的。
- `xx-info vendor` - 目标三元组的供应商组件
- `xx-info libc` - 使用的 libc（musl 或 gnu）

### 构建上下文

- `xx-info is-cross` - 如果目标不是原生架构，则干净退出
- `xx-info env` - 打印定义目标环境的 XX_* 变量

```bash
$ xx-info env
XX_OS=linux
XX_MARCH=x86_64
XX_VENDOR=alpine
XX_PKG_ARCH=x86_64
XX_TRIPLE=x86_64-alpine-linux-musl
XX_LIBC=musl
TARGETOS=linux
TARGETARCH=amd64
TARGETVARIANT=
```

## xx-apk, xx-apt, xx-apt-get - 为目标架构安装软件包

这些脚本允许管理软件包（通常是安装新软件包）来自 Alpine 或 Debian 仓库。它们可以被调用，并接受常规 `apk` 或 `apt/apt-get` 命令接受的任何参数。如果为非原生架构交叉编译，将自动添加目标架构的仓库，并且从那里安装软件包。在 Alpine 上，不允许在同一个根目录下为不同架构安装软件包，因此 `xx-apk` 在次级根目录 `/${triple}` 下安装软件包。这些脚本旨在安装编译器可能需要的头文件和库。为了避免不必要的垃圾，安装时会跳过非原生二进制文件下的 `*/bin`。


```dockerfile
alpine

ARG TARGETPLATFORM
RUN xx-apk add --no-cache musl-dev zlib-dev
```

```dockerfile
debian

ARG TARGETPLATFORM
RUN xx-apt-get install -y libc6-dev zlib1g-dev
```

**注意**
`xx-apt --print-source-file` 可用于打印主要 Apt 源配置文件的路径

还允许安装两个元库 xx-c-essentials 和 xx-cxx-essentials，以扩展任一基础映像所需的最少必要包。

## xx-verify - 验证编译结果

`xx-verify` 允许验证交叉编译工具链是否正确配置，并输出了预期目标平台的二进制文件。`xx-verify` 通过调用 `file` 实用程序并比较预期输出来工作。可以选择性地传递 `--static` 选项来验证编译器是否生成了一个静态二进制文件，可以安全地复制到另一个 Dockerfile 阶段而无需运行时库。如果二进制文件不匹配预期值，xx-verify 会返回非零退出码和错误消息。

```dockerfile
ARG TARGETPLATFORM
RUN xx-clang --static -o /out/myapp app.c && \
    xx-verify --static /out/myapp
```

**注意**
`XX_VERIFY_STATIC=1` 环境变量可以定义，使 `xx-verify` 始终验证编译器生成的是一个静态二进制文件。

## C/C++

基于 C 的构建的推荐方法是通过 xx-clang 包装器使用 clang。Clang 本身是一个交叉编译器，但为了使用它，您还需要一个链接器、编译器 rt 或 libgcc 和一个 C 库（musl 或 glibc）。所有这些都可以在基于 Alpine 和 Debian 的发行版中以软件包的形式获得。Clang 和链接器是二进制文件，应该为您的构建体系结构安装，而 libgcc 和 C 库应该为您的目标体系结构安装。

推荐的链接器是 lld，但有一些注意事项。lld 在 S390x 上不受支持，根据我们的经验，有时在为 Ppc64le 准备静态二进制文件时会出现问题。在这些情况下，需要 binutils 中的 ld。由于需要为每个体系结构构建单独的 ld 二进制文件，发行版通常不将其作为软件包提供。因此，xx 会在需要时加载预构建的 ld 二进制文件。如果您想始终使用 ld，即使系统上有 lld，也可以定义 XX_CC_PREFER_LINKER=ld。构建 MacOS 二进制文件是通过预构建的 ld64 链接器进行的，该链接器还会将临时代码签名添加到生成的二进制文件中。

可以使用 clang 二进制文件接受的任何参数调用 xx-clang，并将在内部调用本机 clang 二进制文件并使用附加配置进行正确的交叉编译。在第一次调用时，xx-clang 还将为当前目标三元组设置别名命令，以后可以直接调用。这有助于使用从 PATH 中查找具有目标三元组前缀的程序的工具。可以通过调用 `xx-clang --setup-target-triple`手动调用此设置阶段，这是一个 clang 本身未实现的特殊标志。

别名命令包括：

- triple-clang, triple-clang++ 如果安装了 clang
- triple-ld 如果使用 ld 作为链接器
- triple-pkg-config 如果安装了 pkg-config
- triple-addr2line, triple-ar, triple-as, triple-ranlib, triple-nm, triple-dlltool, triple-strip 如果通过 llvm 软件包提供了交叉编译能力的工具
- triple-windres 如果安装了 llvm-rc 并且为 Windows 编译

别名命令可以被直接调用，并且总是构建由其名称指定的配置，即使 TARGETPLATFORM 的值已经改变。

### 在 Alpine 上构建

Musl 可以通过以下方式安装

```dockerfile
...

RUN apk add clang lld

复制源代码

ARG TARGETPLATFORM
RUN xx-apk add gcc musl-dev
RUN xx-clang -o hello hello.c && \
    xx-verify hello
```

Clang 二进制文件也可以直接调用，如果你想避免使用 `xx-` 前缀。`--print-target-triple` 是 clang 内置的标志，可以用来查询正确的默认值。

```dockerfile
...

RUN xx-apk add g++
RUN clang++ --target=$(xx-clang --print-target-triple) -o hello hello.cc
```

在第一次调用时，带有 `triple-` 前缀的别名被设置，所以以下内容也有效：

```dockerfile
...

RUN $(xx-clang --print-target-triple)-clang -o hello hello.c
```

如果你希望别名作为一个单独的步骤在单独的层上创建，可以使用 `--setup-target-triple`。

```dockerfile
...

RUN xx-clang --setup-target-triple
RUN $(xx-info)-clang -o hello hello.c
```

### 在 Debian 上构建

在 Debian/Ubuntu 上构建非常相似。唯一需要的依赖是使用 `xx-apt` 安装 libc6-dev 或 libstdc++-N-dev 用于 C++。

```dockerfile
...

RUN apt-get update && apt-get install -y clang lld

复制源代码

ARG TARGETPLATFORM
RUN xx-apt install -y libc6-dev
RUN xx-clang -o hello hello.c
```

参考上一节了解其他变体。

如果你想使用 `GCC` 而不是 `Clang` 进行构建
，你需要使用 `xx-apt-get` 额外安装 gcc 和 binutils 软件包。`xx-apt-get` 将自动安装生成当前目标架构二进制文件的软件包。然后你可以直接调用 GCC，使用正确的目标三元组。请注意，Debian 当前只有在你的原生平台是 amd64 或 arm64 时才提供 GCC 交叉编译软件包。

```dockerfile
...

复制源代码

ARG TARGETPLATFORM
RUN xx-apt-get install -y binutils gcc libc6-dev
RUN $(xx-info)-gcc -o hello hello.c
```

### 包装为默认

特殊情况下，可以使用特殊标志 `xx-clang --wrap` 和 `xx-clang --unwrap` 来覆盖 clang 默认行为，如果构建脚本无法指向替代编译器名称。

```bash

# export TARGETPLATFORM=linux/amd64
# xx-clang --print-target-triple
x86_64-alpine-linux-musl
# clang --print-target-triple
x86_64-alpine-linux-musl
# 
# xx-clang --wrap
# clang --print-target-triple
x86_64-alpine-linux-musl
# xx-clang --unwrap
# clang --print-target-triple
aarch64-alpine-linux-musl
```

## Autotools

Autotools 内置了对交叉编译的支持，通过将 `--host`、`--build` 和 `--target` 标志传递给 `configure` 脚本来实现。`--host` 定义构建结果的目标体系结构，`--build` 定义编译器的本机体系结构（用于编译辅助工具等），`--target` 定义二进制文件作为其他二进制文件的编译器运行时返回的体系结构。通常，只需要 `--host`。
```dockerfile
...

ARG TARGETPLATFORM
RUN ./configure --host=$(xx-clang --print-target-triple) && make
```

如果需要传递 `--build`，你可以暂时重置 `TARGETPLATFORM` 变量以获取系统值。

```dockerfile
ARG TARGETPLATFORM
RUN ./configure --host=$(xx-clang --print-target-triple) --build=$(TARGETPLATFORM= xx-clang --print-target-triple) && make
```

有时配置脚本行为不端，除非直接传递 C 编译器的名称。在这些情况下，我们可以使用如下覆盖：

```dockerfile
RUN CC=xx-clang ./configure ...
```

```dockerfile
RUN ./configure --with-cc=xx-clang ...
```

```dockerfile
RUN ./configure --with-cc=$(xx-clang --print-target-triple)-clang ...
```

## CMake

为了使 CMake 交叉编译更容易，xx-clang 有一个特殊标志 `xx-clang --print-cmake-defines`。运行该命令将返回以下 Cmake 定义：

```
-DCMAKE_C_COMPILER=clang
-DCMAKE_CXX_COMPILER=clang++
-DCMAKE_ASM_COMPILER=clang
-DPKG_CONFIG_EXECUTABLE="$(xx-clang --print-prog-name=pkg-config)"
-DCMAKE_C_COMPILER_TARGET="$(xx-clang --print-target-triple)"
-DCMAKE_CXX_COMPILER_TARGET="$(xx-clang++ --print-target-triple)"
-DCMAKE_ASM_COMPILER_TARGET="$(xx-clang --print-target-triple)"
```

通常，这应该足够获取正确的配置。

```dockerfile
RUN apk add cmake clang lld
ARG TARGETPLATFORM
RUN xx-apk musl-dev gcc
RUN mkdir build && cd build && \
    cmake $(xx-clang --print-cmake-defines) ..
```

## Go / Cgo
可以使用 `xx-go` 包装器来构建 Go，它会自动设置 `GOOS`、`GOARCH`、`GOARM`、`GOAMD64` 等的值。如果使用 CGo 构建，它还会设置 `pkg-config` 和 C 编译器。请注意，默认情况下，在为本机架构编译时，Go 中启用 CGo，而在交叉编译时禁用。这很容易产生意外结果；因此，您应该始终定义 `CGO_ENABLED=1` 或 `CGO_ENABLED=0`，具体取决于您是否希望编译使用 CGo。

```dockerfile
FROM --platform=$BUILDPLATFORM golang:alpine

...

ARG TARGETPLATFORM
ENV CGO_ENABLED=0
RUN xx-go build -o hello ./hello.go && \
    xx-verify hello
```

```dockerfile
FROM --platform=$BUILDPLATFORM golang:alpine
RUN apk add clang lld

...

ARG TARGETPLATFORM
RUN xx-apk add musl-dev gcc
ENV CGO_ENABLED=1
RUN xx-go build -o hello ./hello.go && \
    xx-verify hello
```

如果你想让 go 编译器默认进行交叉编译，可以使用 `xx-go --wrap` 和 `xx-go --unwrap`

```dockerfile
...

RUN xx-go --wrap
RUN go build -o hello hello.go && \
    xx-verify hello
```

## Rust

构建 Rust 可以通过 `xx-cargo` 包装器自动设置目标三元组，并且还 pkg-config 和 C 编译器。

包装器支持通过 rustup 安装的 rust（alpine/debian），分发包（alpine/debian）和官方 rust 镜像。

### 在 Alpine 上构建

```dockerfile
syntax=docker/dockerfile:1

FROM --platform=$BUILDPLATFORM rust:alpine
RUN apk add clang lld

...

ARG TARGETPLATFORM
RUN xx-cargo build --release --target-dir ./build && \
    xx-verify ./build/$(xx-cargo --print-target-triple)/release/hello_cargo
```

Cargo 二进制文件也可以直接调用，如果你不想使用包装器。`--print-target-triple` 是一个内置标志，可以用来设置正确的目标：

```dockerfile
syntax=docker/dockerfile:1

FROM --platform=$BUILDPLATFORM rust:alpine
RUN apk add clang lld

...

ARG TARGETPLATFORM
RUN cargo build --target=$(xx-cargo --print-target-triple) --release --target-dir ./build && \
    xx-verify ./build/$(xx-cargo --print-target-triple)/release/hello_cargo
```

**注意**
`xx-cargo --print-target-triple` 的值并不总是与 `xx-clang --print-target-triple` 的值相同。这是因为预构建的 Rust 和 C 库有时使用不同的值。

第一次调用 xx-cargo 将安装与目标匹配的标准库，如果尚未安装。

要从 `crates.io` 获取依赖项，你可以在构建之前使用 `cargo fetch`：

```dockerfile
syntax=docker/dockerfile:1

FROM --platform=$BUILDPLATFORM rust:alpine
RUN apk add clang lld

...

RUN --mount=type=cache,target=/root/.cargo/git/db \
    --mount=type=cache,target=/root/.cargo/registry/cache \
    --mount=type=cache,target=/root/.cargo/registry/index \
    cargo fetch
ARG TARGETPLATFORM
RUN --mount=type=cache,target=/root/.cargo/git/db \
    --mount=type=cache,target=/root/.cargo/registry/cache \
    --mount=type=cache,target=/root/.cargo/registry/index \
    xx-cargo build --release --target-dir ./build && \
    xx-verify ./build/$(xx-cargo --print-target-triple)/release/hello_cargo
```

**注意**
通过在 `ARG TARGETPLATFORM` 之前调用 `cargo fetch`，你的软件包只需一次获取，整个构建过程中构建是分开进行的。

为了避免在每次构建时重新下载依赖项，你可以使用缓存挂载来存储带有软件包的 `Git` 源和 `crate` 注册表的元数据。

如果你不想使用官方 Rust 镜像，你可以手动安装 rustup：

```dockerfile
syntax=docker/dockerfile:1

FROM --platform=$BUILDPLATFORM alpine AS rustup
RUN apk add curl
RUN curl https://sh.rustup.rs -sSf | sh -s -- -y --default-toolchain stable --no-modify-path --profile minimal
ENV PATH="/root/.cargo/bin:$PATH"

FROM rustup
RUN apk add clang lld

...

ARG TARGETPLATFORM
RUN xx-cargo build --release --target-dir ./build && \
    xx-verify ./build/$(xx-cargo --print-target-triple)/release/hello_cargo
```

如果你使用分发包安装 rust，rustup 将不可用：

```dockerfile
syntax=docker/dockerfile:1

FROM --platform=$BUILDPLATFORM alpine
RUN apk add clang lld rust cargo

...

ARG TARGETPLATFORM
RUN xx-apk add xx-c-essentials
RUN xx-cargo build --release --target-dir ./build && \
    xx-verify ./build/$(xx-cargo --print-target-triple)/release/hello_cargo
```

在这种情况下，我们需要使用 `xx-apk` 安装最低必要的软件包。

### 在 Debian 上构建

在 Debian/Ubuntu 上构建非常相似。如果你使用 rustup：

```dockerfile
syntax=docker/dockerfile:1

FROM --platform=$BUILDPLATFORM rust:bookworm
RUN apt-get update && apt-get install -y clang lld
ARG TARGETPLATFORM
RUN xx-cargo build --release --target-dir ./build && \
    xx-verify ./build/$(xx-cargo --print-target-triple)/release/hello_cargo
```

```dockerfile
syntax=docker/dockerfile:1

FROM --platform=$BUILDPLATFORM debian:bookworm AS rustup
RUN apt-get update && apt-get install -y curl ca-certificates
RUN curl https://sh.rustup.rs -sSf | sh -s -- -y --default-toolchain stable --no-modify-path --profile minimal
ENV PATH="/root/.cargo/bin:$PATH"

FROM rustup
RUN apt-get update && apt-get install -y clang lld

...

ARG TARGETPLATFORM
RUN xx-cargo build --release --target-dir ./build && \
    xx-verify ./build/$(xx-cargo --print-target-triple)/release/hello_cargo
```

或分发包：

```dockerfile
syntax=docker/dockerfile:1

FROM --platform=$BUILDPLATFORM debian:bookworm
RUN apt-get update && apt-get install -y clang lld cargo
ARG TARGETPLATFORM
RUN xx-apt-get install xx-c-essentials
RUN xx-cargo build --release --target-dir
 ./build && \
    xx-verify ./build/$(xx-cargo --print-target-triple)/release/hello_cargo
```

## 外部 SDK 支持

除了 `Linux` 目标平台，xx 还可以构建 `MacOS` 和 `Windows` 二进制文件。当从 C 构建 MacOS 二进制文件时，需要在 `/xx-sdk` 目录中有一个外部 `MacOS SDK`。这样的 SDK 可以例如使用 `osxcross` 项目中的 `gen_sdk_package` 脚本来构建。请在制作这样的镜像时咨询 `XCode` 许可条款。`RUN --mount` 语法可以在 Dockerfile 中使用，以避免复制 SDK 文件。本身不需要特殊工具，如 `ld64` 链接器。

从 C/CGo 构建 Windows 二进制文件目前仍在进行中，尚不可用。

```dockerfile
syntax=docker/dockerfile:1.2

...

RUN apk add clang lld
ARG TARGETPLATFORM
RUN --mount=from=my/sdk-image,target=/xx-sdk,src=/xx-sdk \
    xx-clang -o /hello hello.c && \
    xx-verify /hello

FROM scratch
COPY --from=build /hello /
```

```bash
docker buildx build --platform=darwin/amd64,darwin/arm64 -o bin .
```

`o/--output` 标志可以用来从构建器中导出二进制文件，而无需创建容器镜像。
