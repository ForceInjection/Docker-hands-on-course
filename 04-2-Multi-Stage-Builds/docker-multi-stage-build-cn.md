# 如何构建更小的容器镜像：Docker 多阶段构建

如果你使用 `Docker` 构建容器镜像，而你的 `Dockerfile` 没有使用多阶段构建，那么你很可能会将不必要的臃肿内容带到生产环境中。这不仅增加了镜像的大小，还扩大了其潜在的攻击面。

究竟是什么导致了这种臃肿，又该如何避免呢？

在本文中，我们将探讨生产容器镜像中不必要的软件包最常见的来源。一旦问题明确，我们将看到如何使用[多阶段构建](https://docs.docker.com/build/building/multi-stage/)来生成更小、更安全的镜像。最后，我们将练习为一些流行的软件栈重构 `Dockerfile`，以便更好地内化新知识，并展示通常只需一点点额外努力就能显著改善镜像。

让我们开始吧！

## 为什么我的镜像这么大？

几乎任何应用程序，无论其类型（`Web` 服务、数据库、`CLI` 等）或语言栈（`Python`、`Node.js`、`Go` 等），都有两种类型的依赖项：构建时依赖和运行时依赖。

通常，构建时依赖比运行时依赖更多且更复杂（即包含更多的 `CVE`）。因此，在大多数情况下，你只希望在最终镜像中包含生产依赖项。

然而，构建时依赖项经常出现在生产容器中，主要原因之一是：

> **使用完全相同的镜像来构建和运行应用程序。**

在容器中构建代码是一种常见（且良好）的做法——它保证了构建过程在开发人员的机器、`CI` 服务器或任何其他环境中使用相同的工具集。

如今，在容器中运行应用程序已成为事实上的标准做法。即使你没有使用 Docker，你的代码很可能仍然在容器或[类似容器的虚拟机](https://iximiuz.com/en/posts/oci-containers/)中运行。

然而，构建和运行应用程序是两个完全不同的问题，具有不同的需求和约束。因此，**构建镜像和运行时镜像也应该是完全分开的！** 尽管如此，这种分离的需求经常被忽视，导致生产镜像中包含了 `linter`(一种用于静态代码分析的工具，主要用于检查代码中的语法错误、风格问题、潜在的 `bug` 以及不符合编码规范的地方)、编译器和其他开发工具。

以下是一些示例，展示了这种情况通常是如何发生的。

### `Go` 应用程序 `Dockerfile` 的**错误**组织方式

从一个更明显的例子开始：

```dockerfile
# 不要在 Dockerfile 中这样做
FROM golang:1.23

WORKDIR /app
COPY . .

RUN go build -o binary

CMD ["/app/binary"]
```

上述 `Dockerfile` 的问题在于，[`golang`](https://hub.docker.com/_/golang) 镜像从未被设计为生产应用程序的基础镜像。然而，如果你想在容器中构建 `Go` 代码，这个镜像是默认选择。但一旦你编写了一段将源代码编译为可执行文件的 `Dockerfile`，很容易简单地添加一个 `CMD` 指令来调用这个二进制文件，然后就认为完成了。

![Go 应用程序的单阶段 Dockerfile。](https://labs.iximiuz.com/content/files/tutorials/docker-multi-stage-builds/__static__/single-stage-go.png)

_`Go` 应用程序 `Dockerfile` 的错误示范。_

问题在于，这样的镜像不仅包含应用程序本身（你希望在生产环境中使用的部分），还包含整个 `Go` 编译器工具链及其所有依赖项（你绝对不希望在生产环境中使用的部分）：

```bash
trivy image -q golang:1.23
```

```
golang:1.23 (debian 12.7)

Total: 799 (UNKNOWN: 0, LOW: 240, MEDIUM: 459, HIGH: 98, CRITICAL: 2)
```

`golang:1.23` 镜像带来了超过 `800MB` 的软件包和大约相同数量的 `CVE`。

### `Node.js` 应用程序 `Dockerfile` 的**错误**组织方式

一个类似但稍微更隐蔽的例子：

```dockerfile
# 不要在 Dockerfile 中这样做
FROM node:22-slim

WORKDIR /app
COPY . .

RUN npm ci
RUN npm run build

ENV NODE_ENV=production
EXPOSE 3000

CMD ["node", "/app/.output/index.mjs"]
```

与 `golang` 镜像不同，[`node:22-slim` 是一个有效的生产工作负载基础镜像](https://labs.iximiuz.com/tutorials/how-to-choose-nodejs-container-image)。然而，这个 `Dockerfile` 仍然存在潜在问题。如果你使用它构建镜像，最终可能会得到以下组成：

![Node.js 应用程序的单阶段 Dockerfile。](https://labs.iximiuz.com/content/files/tutorials/docker-multi-stage-builds/__static__/single-stage-nodejs.png)

_`Node.js` 应用程序 `Dockerfile` 的错误示范。_

该图显示了 `iximiuz Labs` 前端应用的实际数据，该应用是用 `Nuxt 3` 编写的。如果它使用上述单阶段 `Dockerfile`，生成的镜像将包含近 `500MB` 的 `node_modules`，而只有大约 `50MB` 的“**打包**”`JavaScript`（和静态资源）在 `.output` 文件夹中构成了（自给自足的）生产应用。

这一次，“**臃肿**”是由 `npm ci` 步骤引起的，它安装了生产和开发依赖项。但问题不能简单地通过使用 `npm ci --omit=dev` 来解决，因为它会破坏后续的 `npm run build` 命令，该命令需要生产和开发依赖项来生成最终的应用程序包。因此，需要一个更巧妙的解决方案。

## 多阶段构建之前如何生成精简镜像

在前一节的 `Go` 和 `Node.js` 示例中，解决方案可能涉及将原始 `Dockerfile` 拆分为两个文件。

第一个 `Dockerfile`(`Dockerfile.build`) 将以 `FROM <sdk-image>` 开头，并包含应用程序构建指令：

```dockerfile
FROM node:22-slim

WORKDIR /app
COPY . .

RUN npm ci
RUN npm run build
```

使用 `Dockerfile.build` 运行 `docker build` 命令将生成一个辅助镜像：

```bash
docker build -t build:v1 -f Dockerfile.build .
```

...然后可以使用该镜像将构建的应用（我们的制品）[提取到构建主机](https://labs.iximiuz.com/tutorials/extracting-container-image-filesystem)：

```bash
docker cp $(docker create build:v1):/app/.output .
```

第二个 `Dockerfile`(`Dockerfile.run`) 将以 `FROM <runtime-image>` 开头，并简单地将构建的应用从主机复制到其未来的运行时环境中：


```bash
FROM node:22-slim

WORKDIR /app
COPY .output .

ENV NODE_ENV=production
EXPOSE 3000

CMD ["node", "/app/.output/index.mjs"]
```

第二次使用 `Dockerfile.run` 运行 `docker build` 命令将生成最终的精简生产镜像：

```bash
docker build -t app:v1 -f Dockerfile.run .
```

这种技术被称为[**构建器模式**](https://blog.alexellis.io/mutli-stage-docker-builds/)，在 `Docker` 添加多阶段构建支持之前被广泛使用。

![Go 应用程序的构建器模式。](https://labs.iximiuz.com/content/files/tutorials/docker-multi-stage-builds/__static__/builder-pattern-go.png)

![Node.js 应用程序的构建器模式。](https://labs.iximiuz.com/content/files/tutorials/docker-multi-stage-builds/__static__/builder-pattern-nodejs.png)

然而，虽然功能齐全，但构建器模式的用户体验相对较差。它需要：

* 编写多个相互依赖的 `Dockerfile`。
* 将构建制品复制到构建主机并从构建主机复制。
* 设计额外的脚本来执行 `docker build` 命令。

此外，还需要记住始终在 `docker build -f Dockerfile.run` 命令之前运行 `docker build -f Dockerfile.build` 命令（否则，最终镜像可能会使用之前构建的陈旧制品），并且通过主机发送构建制品的体验也远非完美。

与此同时，“**原生**”构建器模式实现可以：

* 优化制品复制;
* 简化构建顺序的组织;
* 在不同团队之间标准化该技术。

幸运的是，`Docker` 后来实现了多阶段构建！

## 理解多阶段构建的简单方法

本质上，**多阶段构建是构建器模式的增强版**，直接在 `Docker` 中实现。要理解多阶段构建的工作原理，熟悉两个看似独立但更简单的 `Dockerfile` 功能非常重要。

### 你可以从另一个镜像中 `COPY` 文件

最常用的 `Dockerfile` 指令之一是 `COPY`。大多数时候，我们从主机复制文件到容器镜像：

```bash
COPY host/path/to/file image/path/to/file
```

然而，你也可以[直接从其他镜像中复制文件](https://docs.docker.com/reference/dockerfile/#copy---from) 

以下是一个示例，它将 `nginx.conf` 文件从 `Docker Hub` 的 `nginx:latest` 镜像复制到当前正在构建的镜像中：

```bash
COPY --from=nginx:latest /etc/nginx/nginx.conf /nginx.conf
```

这个功能在实现构建器模式时**也非常有用**。现在，我们可以直接从辅助构建镜像中复制构建的制品：

```bash
FROM node:22-slim

WORKDIR /app
COPY --from=build:v1 /app/.output .

ENV NODE_ENV=production
EXPOSE 3000

CMD ["node", "/app/.output/index.mjs"]
```

因此，`COPY --from=<image>` 技巧**使得在从构建镜像复制制品到运行时镜像时绕过构建主机成为可能**。

然而，编写多个 `Dockerfile` 的需求和构建顺序依赖问题仍然存在...

### 你可以在一个 Dockerfile 中定义多个镜像

历史上，`Dockerfile`(`Dockerfile.simple`) 以 `FROM <base-image>` 指令开头：

```bash
FROM node:22-slim
COPY ...
RUN ["node", "/path/to/app"]
```

...然后 `docker build` 命令将使用它生成一个镜像：

```bash
docker build -f Dockerfile.simple -t app:latest .
```

然而，自 2018 年左右以来，`Docker` 支持复杂的“**多租户**”`Dockerfile`。你可以在一个 `Dockerfile`(`Dockerfile.complex`) 中放入任意多个**命名**的 `FROM` 指令：

```dockerfile
FROM busybox:stable AS from1
CMD ["echo", "busybox"]

FROM alpine:3 AS from2
CMD ["echo", "alpine"]

FROM debian:stable-slim AS from3
CMD ["echo", "debian"]
```

...每个 `FROM` 都将成为 [`docker build` 命令的单独目标](https://docs.docker.com/reference/cli/docker/buildx/build/#target)：

```bash
docker build -f Dockerfile.complex --target from1 -t my-busybox
docker run my-busybox
```

同一个 `Dockerfile`，但生成完全不同的镜像：

```bash
docker build -f Dockerfile.complex --target from2 -t my-alpine
docker run my-alpine
```

...同一个 `Dockerfile` 生成的另一个镜像：

```bash
docker build -f Dockerfile.complex --target from3 -t my-debian
docker run my-debian
```

回到我们的构建器模式问题，这意味着我们可以使用一个复合 `Dockerfile` 中的两个不同 `FROM` 指令将**构建**和**运行时** `Dockerfile` 重新组合在一起！

### 多阶段 Dockerfile 的强大功能

以下是一个“**复合**”`Node.js` 应用程序 `Dockerfile` 的示例：

```dockerfile
# "构建"阶段
FROM node:22-slim AS build

WORKDIR /app
COPY . .

RUN npm ci
RUN npm run build

# "运行时"阶段
FROM node:22-slim AS runtime

WORKDIR /app
COPY --from=build /app/.output .

ENV NODE_ENV=production
EXPOSE 3000

CMD ["node", "/app/.output/index.mjs"]
```

使用官方术语，每个 `FROM` 指令定义的不是一个镜像，而是一个**阶段**，从技术上讲，`COPY` 是从一个阶段进行的。然而，正如我们上面看到的，将**阶段**视为独立的镜像有助于理解。

最后但同样重要的是，当所有阶段和 `COPY --from=<stage>` 指令都在一个 Dockerfile 中定义时，Docker 构建引擎（BuildKit）可以计算正确的构建顺序，跳过未使用的阶段，并并行执行独立的阶段 🧙

![Node.js 应用程序的多阶段 Dockerfile 示例。](https://labs.iximiuz.com/content/files/tutorials/docker-multi-stage-builds/__static__/multi-stage-build.png)

在编写第一个多阶段 `Dockerfile` 之前，需要记住几个重要的事实：

* `Dockerfile` 中阶段的顺序很重要——无法从当前阶段下方的阶段进行 `COPY --from`;
* `AS` 别名是可选的——如果你不为阶段命名，仍然可以通过它们的序列号引用它们;
* 当不使用 `--target` 标志时，`docker build` 命令将构建最后一个阶段（以及它从中复制的所有阶段）.

## 多阶段构建实践

以下是如何使用多阶段构建为不同语言和框架生成更小、更安全的容器镜像的示例。

### Node.js

`Node.js` 应用程序有不同形式和形状——有些在开发和构建阶段只需要 `Node.js`，而其他一些在运行时容器中也需要 `Node.js`。

以下是一些如何为 `Node.js` 应用程序构建多阶段 `Dockerfile` 的示例：

#### 多阶段构建示例：React 应用程序

纯 [React](https://react.dev/) 应用程序在构建后不依赖于 `Node.js`，因此它们可以由任何静态文件服务器提供服务。然而，构建过程需要 `Node.js`、`npm` 和 `package.json` 中的所有依赖项。因此，仔细地从[可能庞大的构建镜像](https://labs.iximiuz.com/tutorials/how-to-choose-nodejs-container-image)中“挑选”静态构建制品非常重要。

```dockerfile
# 小技巧：为所有阶段定义一次 Node.js 镜像。
# 通常，建议坚持使用当前的 LTS 版本。
FROM node:22-slim AS base

# 优化：仅在 package.json 或 package-lock.json 文件更改时重新安装依赖项。
FROM base AS deps
WORKDIR /app

COPY package*.json ./
RUN npm ci

# 在容器中运行测试，重用已安装的依赖项。
FROM deps AS test
WORKDIR /app

RUN npm test

# 构建阶段
FROM base AS build
WORKDIR /app

# 重要：将 node_modules 添加到 .dockerignore 文件中，
# 以避免覆盖 deps 阶段的 node_modules。
COPY --from=deps /app/node_modules ./node_modules
COPY . .
RUN npm run build

# 运行时阶段
FROM nginx:alpine
WORKDIR /usr/share/nginx/html

RUN rm -rf ./*
COPY --from=build /app/build .

ENTRYPOINT ["nginx", "-g", "daemon off;"]
```

#### 多阶段构建示例：Next.js 应用程序

[Next.js](https://nextjs.org/) 应用程序可以是：

* [完全静态的](https://nextjs.org/docs/app/building-your-application/deploying/static-exports)：构建过程和多阶段 `Dockerfile` 几乎与上述 `React` 示例相同；
* [具有服务器端功能的](https://nextjs.org/docs/app/building-your-application/deploying#docker-image)：构建过程与 `React` 类似，但运行时镜像也需要 `Node.js`。

以下是一个具有服务器端功能的 `Next.js` 应用程序的多阶段 `Dockerfile` 示例：

```dockerfile
# 小技巧：为所有阶段定义一次 Node.js 镜像。
# 通常，建议坚持使用当前的 LTS 版本。
FROM node:22-slim AS base

# 优化：仅在 package.json 或 package-lock.json 文件更改时重新安装依赖项。
FROM base AS deps
WORKDIR /app

COPY package*.json ./
RUN npm ci

# 在容器中运行测试，重用已安装的依赖项。
FROM deps AS test
WORKDIR /app

RUN npm test

# 构建阶段
FROM base AS build
WORKDIR /app

# 重要：将 node_modules 添加到 .dockerignore 文件中，
# 以避免覆盖 deps 阶段的 node_modules。
COPY --from=deps /app/node_modules ./node_modules
COPY . .
RUN npm run build

# 运行时阶段
FROM base AS runtime
WORKDIR /app

COPY --from=build /app/public ./public
COPY --from=build --chown=node:node /app/.next/standalone ./
COPY --from=build --chown=node:node /app/.next/static ./.next/static

ENV NODE_ENV=production

ENV HOSTNAME="0.0.0.0"
ENV PORT=3000

EXPOSE 3000
USER node

CMD ["node", "server.js"]
```

#### 多阶段构建示例：`Vue` 应用程序

从构建过程的角度来看，[Vue](https://vuejs.org/) 应用程序与 `React` 应用程序非常相似。构建过程需要 `Node.js`、`npm` 和 `package.json` 中的所有依赖项，但生成的构建制品是静态文件，可以由任何静态文件服务器提供服务。

```dockerfile
# 小技巧：为所有阶段定义一次 Node.js 镜像。
# 通常，建议坚持使用当前的 LTS 版本。
FROM node:22-slim AS base

# 优化：仅在 package.json 或 package-lock.json 文件更改时重新安装依赖项。
FROM base AS deps
WORKDIR /app

COPY package*.json ./
RUN npm ci

# 在容器中运行测试，重用已安装的依赖项。
FROM deps AS test
WORKDIR /app

RUN npm test

# 构建阶段
FROM base AS build
WORKDIR /app

# 重要：将 node_modules 添加到 .dockerignore 文件中，
# 以避免覆盖 deps 阶段的 node_modules。
COPY --from=deps /app/node_modules ./node_modules
COPY . .
RUN npm run build

# 运行时阶段
FROM nginx:alpine
WORKDIR /usr/share/nginx/html

RUN rm -rf ./*
COPY --from=build /app/dist .
```

#### 多阶段构建示例：Nuxt 应用程序

与 `Next.js` 类似，[Nuxt](https://nuxt.com/) 应用程序可以是完全静态的，也可以是[具有服务器端支持的](https://nuxt.com/docs/getting-started/deployment#nodejs-server)。以下是一个在 `Node.js` 服务器上运行的 `Nuxt` 应用程序的多阶段 `Dockerfile` 示例：

```dockerfile
# 小技巧：为所有阶段定义一次 Node.js 镜像。
# 通常，建议坚持使用当前的 LTS 版本。
FROM node:22-slim AS base

# 优化：仅在 package.json 或 package-lock.json 文件更改时重新安装依赖项。
FROM base AS deps
WORKDIR /app

COPY package*.json ./
RUN npm ci

# 在容器中运行测试，重用已安装的依赖项。
FROM deps AS test
WORKDIR /app

RUN npm test

# 构建阶段
FROM base AS build
WORKDIR /app

# 重要：将 node_modules 添加到 .dockerignore 文件中，
# 以避免覆盖 deps 阶段的 node_modules。
COPY --from=deps /app/node_modules ./node_modules
COPY . .
RUN npm run build

# 运行时阶段
FROM base AS runtime
WORKDIR /app

COPY --from=build --chown=node:node /app/.output  .

ENV NODE_ENV=production
ENV NUXT_ENVIRONMENT=production

ENV NITRO_HOST=0.0.0.0
ENV NITRO_PORT=8080

EXPOSE 8080
USER node:node

CMD ["node", "server/index.mjs"]
```

### Go

`Go` 应用程序总是在构建阶段编译。然而，生成的二进制文件可以是静态链接的（`CGO_ENABLED=0`）或动态链接的（`CGO_ENABLED=1`）。运行时阶段的基础镜像选择将取决于生成的二进制文件的类型：

* 对于静态链接的二进制文件，你可以选择极简的 [`gcr.io/distroless/static`](https://iximiuz.com/en/posts/containers-distroless-images/) 甚至 `scratch` 基础镜像（后者需格外小心）；
* 对于动态链接的二进制文件，需要一个包含标准共享 C 库的基础镜像（例如 `gcr.io/distroless/cc`、`alpine` 或 `debian`）。

在大多数情况下，运行时基础镜像的选择不会影响多阶段 `Dockerfile` 的结构。

#### 多阶段构建示例：Go 应用程序

```dockerfile
# 构建阶段
FROM golang:1.23 AS build
WORKDIR /app

# 优化：仅在 go.mod 或 go.sum 文件更改时重新下载依赖项。
COPY go.* ./
RUN go mod download

COPY . .
RUN CGO_ENABLED=0 go build -o binary .

# 在容器中运行测试，重用已编译的依赖项。
FROM build AS test
WORKDIR /app

RUN go test -v ./...

# 运行时阶段
FROM gcr.io/distroless/static-debian12:nonroot

COPY --from=build /app/binary /app/binary

CMD ["/app/binary"]
```

### Rust

[Rust](https://www.rust-lang.org/) 应用程序通常使用 `cargo` 从源代码编译。`Docker` 官方的 [`rust`](https://hub.docker.com/_/rust) 镜像包含 `cargo`、`rustc` 和许多其他开发和构建工具，使得镜像的总大小接近 2GB。对于 Rust 应用程序来说，多阶段构建是保持运行时镜像小巧的必备工具。请注意，运行时基础镜像的最终选择将取决于 `Rust` 应用程序的库需求。

#### 多阶段构建示例：Rust 应用程序

```dockerfile
# 构建阶段
FROM rust:1.67 AS build

WORKDIR /usr/src/app

COPY . .
RUN cargo install --path .

# 运行时阶段
FROM debian:bullseye-slim

RUN apt-get update && \
    apt-get install -y extra-runtime-dependencies && \
    rm -rf /var/lib/apt/lists/*

COPY --from=build /usr/local/cargo/bin/app /usr/local/bin/app

CMD ["myapp"]
```

### Java

`Java` 应用程序使用 `Maven` 或 `Gradle` 等构建工具从源代码编译，并需要 `Java` 运行时环境（`JRE`）来执行。

对于容器化的 `Java` 应用程序，通常为构建和运行时阶段使用不同的基础镜像。构建阶段需要 `Java `开发工具包（`JDK`），其中包含编译和打包代码的工具，而运行时阶段通常只需要更小、更轻量级的 `Java` 运行时环境（`JRE`）来执行。

#### 多阶段构建示例：Java 应用程序

此示例改编自[官方 Docker 文档](https://docs.docker.com/guides/java/run-tests/#run-tests-when-building)。`Dockerfile` 比之前的示例更复杂，因为它包含一个额外的测试阶段，并且 Java 构建过程涉及比 `Node.js` 和 `Go` 应用程序更复杂的步骤。

```dockerfile
# 基础阶段（由测试和开发阶段重用）
FROM eclipse-temurin:21-jdk-jammy AS base

WORKDIR /build

COPY --chmod=0755 mvnw mvnw
COPY .mvn/ .mvn/

# 测试阶段
FROM base as test

WORKDIR /build

COPY ./src src/
RUN --mount=type=bind,source=pom.xml,target=pom.xml \
    --mount=type=cache,target=/root/.m2 \
    ./mvnw test

# 中间阶段
FROM base AS deps

WORKDIR /build

RUN --mount=type=bind,source=pom.xml,target=pom.xml \
    --mount=type=cache,target=/root/.m2 \
    ./mvnw dependency:go-offline -DskipTests

# 中间阶段
FROM deps AS package

WORKDIR /build

COPY ./src src/
RUN --mount=type=bind,source=pom.xml,target=pom.xml \
    --mount=type=cache,target=/root/.m2 \
    ./mvnw package -DskipTests && \
    mv target/$(./mvnw help:evaluate -Dexpression=project.artifactId -q -DforceStdout)-$(./mvnw help:evaluate -Dexpression=project.version -q -DforceStdout).jar target/app.jar

# 构建阶段
FROM package AS extract

WORKDIR /build

RUN java -Djarmode=layertools -jar target/app.jar extract --destination target/extracted

# 开发阶段
FROM extract AS development

WORKDIR /build

RUN cp -r /build/target/extracted/dependencies/. ./
RUN cp -r /build/target/extracted/spring-boot-loader/. ./
RUN cp -r /build/target/extracted/snapshot-dependencies/. ./
RUN cp -r /build/target/extracted/application/. ./

ENV JAVA_TOOL_OPTIONS="-agentlib:jdwp=transport=dt_socket,server=y,suspend=n,address=*:8000"

CMD [ "java", "-Dspring.profiles.active=postgres", "org.springframework.boot.loader.launch.JarLauncher" ]

# 运行时阶段
FROM eclipse-temurin:21-jre-jammy AS runtime

ARG UID=10001

RUN adduser \
    --disabled-password \
    --gecos "" \
    --home "/nonexistent" \
    --shell "/sbin/nologin" \
    --no-create-home \
    --uid "${UID}" \
    appuser

USER appuser

COPY --from=extract build/target/extracted/dependencies/ ./
COPY --from=extract build/target/extracted/spring-boot-loader/ ./
COPY --from=extract build/target/extracted/snapshot-dependencies/ ./
COPY --from=extract build/target/extracted/application/ ./

EXPOSE 8080
ENTRYPOINT [ "java", "-Dspring.profiles.active=postgres", "org.springframework.boot.loader.launch.JarLauncher" ]
```

### PHP

[`PHP`](https://www.php.net/) 应用程序是从源代码解释的，因此不需要编译。然而，开发和生产所需的依赖项通常不同，因此通常建议使用多阶段构建来仅安装生产依赖项，并将它们复制到运行时镜像中。

#### 多阶段构建示例：PHP 应用程序

```dockerfile
# 安装依赖项阶段
FROM composer:lts AS deps

WORKDIR /app

COPY composer.json composer.lock ./

RUN --mount=type=cache,target=/tmp/cache \
    composer install --no-dev --no-interaction


# 运行时阶段
FROM php:8-apache AS runtime

RUN docker-php-ext-install pdo pdo_mysql
RUN mv "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini"

COPY ./src /var/www/html
COPY --from=deps /app/vendor/ /var/www/html/vendor

USER www-data
```

## 结论

生产镜像经常受到“**遗忘**”的开发软件包的影响，增加了不必要的臃肿和安全风险。多阶段构建通过让我们将构建和运行时环境分开，同时将它们描述在一个 `Dockerfile` 中，从而解决了这个问题，使得构建更加高效。正如我们所看到的，一些简单的调整可以减少镜像大小、提高安全性，并使构建脚本更简洁、更易于维护。

多阶段构建还支持许多[**高级用例**](https://www.docker.com/blog/advanced-dockerfiles-faster-builds-and-smaller-images-using-buildkit-and-multistage-builds/)，例如条件 `RUN` 指令（分支）、在 `docker build` 步骤中进行单元测试等。开始使用多阶段构建，以保持你的容器精简且适合生产环境。