# Docker - 基本命令
- 以下是我们需要的基本命令列表

|命令|描述|
|---|---|
|`docker ps`|列出所有正在运行的容器|
|`docker ps -a`|列出所有容器（包括已停止和正在运行的）。便于查看所有容器的状态。|
|`docker stop 容器ID`|停止正在运行的容器|
|`docker start 容器ID`|启动已停止的容器|
|`docker restart 容器ID`|重启正在运行的容器|
|`docker port 容器ID`|列出特定容器的端口映射|
|`docker rm 容器ID或名称`|删除已停止的容器|
|`docker rm -f 容器ID或名称`|强制删除正在运行的容器，即使容器正在运行也会被停止并删除。请谨慎使用。|
|`docker pull 镜像信息`|从 Docker Hub 仓库拉取镜像|
|`docker pull stacksimplify/springboot-helloworld-rest-api:2.0.0-RELEASE`|从 Docker Hub 仓库拉取指定版本的镜像|
|`docker exec -it 容器名称 /bin/sh`|连接到 Linux 容器并在容器内执行命令，适合调试或执行容器内命令。|
|`docker rmi 镜像ID`|删除 Docker 镜像。如果镜像被某个容器依赖，需先删除相关容器。|
|`docker logout`|从 Docker Hub 注销|
|`docker login -u 用户名 -p 密码`|登录到 Docker Hub|
|`docker stats`|显示容器资源使用统计信息的实时流，包括 CPU、内存、网络 I/O 等，适合用于性能监控。|
|`docker top 容器ID或名称`|显示容器的运行进程|
|`docker version`|显示 Docker 版本信息|
|`docker build -t 镜像名 .`|从当前目录的 Dockerfile 构建镜像，例如：`docker build -t my_image .`|
|`docker images`|列出所有本地镜像|
|`docker network ls`|列出所有 Docker 网络，例如：`docker network ls`，显示网络名称、驱动和范围。|
|`docker network inspect 网络名`|查看特定网络的详细信息|
|`docker volume ls`|列出所有 Docker 数据卷，例如：`docker volume ls`。|
|`docker volume inspect 卷名`|查看指定数据卷的详细信息|

### 补充说明：
- **`docker ps -a`**：该命令会列出所有容器，包括正在运行的和已停止的。这对于查看所有容器的状态非常有用。
- **`docker rm -f`**：强制删除容器时，即使容器正在运行也会被强制停止并删除。请谨慎使用此命令。
- **`docker exec -it`**：该命令允许你进入容器的交互式终端，通常用于调试或执行容器内的命令。
- **`docker stats`**：该命令会实时显示容器的 CPU、内存、网络 I/O 等资源使用情况，非常适合监控容器的性能。
- **`docker rmi`**：删除镜像时，确保没有容器依赖于该镜像，否则删除操作会失败。

这些命令是 Docker 日常使用中最基本和常用的操作，掌握它们可以帮助你更好地管理和维护 Docker 容器和镜像。