# 参考文档

- [How to build docker images on Apple M-series](https://www.izumanetworks.com/blog/build-docker-on-apple-m/)
- [Faster Multi-Platform Builds: Dockerfile Cross-Compilation Guide](https://www.docker.com/blog/faster-multi-platform-builds-dockerfile-cross-compilation-guide/)
- [Multi-platform builds](https://docs.docker.com/build/building/multi-platform/)

# 安装 docker buildx

Linux x86_64 上安装 docker buildx:

```bash
mkdir -p ~/.docker/cli-plugins/
curl -SL https://github.com/docker/buildx/releases/latest/download/docker-buildx-linux-amd64 -o ~/.docker/cli-plugins/docker-buildx
chmod +x ~/.docker/cli-plugins/docker-buildx
```

# 多平台构建

采用了多步构建，详细参考[**Dockerfile**](Dockerfile-multi-platform).

关于`xx` 工具的信息，请查看[tonistiigi/xx](xx-tool.md).

- **本地构建完，查看镜像信息**

```bash
docker buildx build -f Dockerfile-multi-platform --platform linux/arm64 --tag multi-platform:latest --load .
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
 => CACHED [builder 2/8] RUN DEBIAN_FRONTEND=noninteractive apt-get update &&     DEBIAN_FRONTEND=noninteractive apt-get -y install build-essential &&     DEBIAN_FRONTEND=noninteractive apt-get -y clean       0.0s
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

docker images | grep multi
multi-platform                        latest    f62af6260d60   2 hours ago   66.3MB


docker inspect f62af6260d60 | grep -i arch
        "Architecture": "arm64",
```

- **同时多平台构建，并推送到镜像仓库（以 Docker hub 为例）**

```bash
docker buildx build -f Dockerfile-multi-platform --platform linux/amd64,linux/arm64 --tag grissomsh/go-multi-platform:latest --push .
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
 => => resolve docker.io/library/golang:1.23@sha256:2fe82a3f3e006b4f2a316c6a21f62b66e1330ae211d039bb8d1128e12ed57bf1                                                                                             0.0s
 => [linux/arm64 stage-2 1/3] FROM docker.io/library/debian:buster-slim@sha256:bb3dc79fddbca7e8903248ab916bb775c96ec61014b3d02b4f06043b604726dc                                                                  0.0s
 => => resolve docker.io/library/debian:buster-slim@sha256:bb3dc79fddbca7e8903248ab916bb775c96ec61014b3d02b4f06043b604726dc                                                                                      0.0s
 => [linux/amd64 stage-2 1/3] FROM docker.io/library/debian:buster-slim@sha256:bb3dc79fddbca7e8903248ab916bb775c96ec61014b3d02b4f06043b604726dc                                                                  0.0s
 => => resolve docker.io/library/debian:buster-slim@sha256:bb3dc79fddbca7e8903248ab916bb775c96ec61014b3d02b4f06043b604726dc                                                                                      0.0s
 => [internal] load build context                                                                                                                                                                                0.0s
 => => transferring context: 55B                                                                                                                                                                                 0.0s
 => FROM docker.io/tonistiigi/xx:latest@sha256:0c6a569797744e45955f39d4f7538ac344bfb7ebf0a54006a0a4297b153ccf0f                                                                                                  0.0s
 => => resolve docker.io/tonistiigi/xx:latest@sha256:0c6a569797744e45955f39d4f7538ac344bfb7ebf0a54006a0a4297b153ccf0f                                                                                            0.0s
 => FROM docker.io/tonistiigi/xx:latest@sha256:0c6a569797744e45955f39d4f7538ac344bfb7ebf0a54006a0a4297b153ccf0f                                                                                                  0.0s
 => => resolve docker.io/tonistiigi/xx:latest@sha256:0c6a569797744e45955f39d4f7538ac344bfb7ebf0a54006a0a4297b153ccf0f                                                                                            0.0s
 => CACHED [linux/arm64 builder 2/8] RUN DEBIAN_FRONTEND=noninteractive apt-get update &&     DEBIAN_FRONTEND=noninteractive apt-get -y install build-essential &&     DEBIAN_FRONTEND=noninteractive apt-get -  0.0s
 => CACHED [linux/arm64 builder 3/8] COPY --from=tonistiigi/xx / /                                                                                                                                               0.0s
 => CACHED [linux/arm64 builder 4/8] ADD app /app                                                                                                                                                                0.0s
 => CACHED [linux/arm64 builder 5/8] RUN xx-apt install -y libc6-dev gcc                                                                                                                                         0.0s
 => CACHED [linux/arm64 builder 6/8] WORKDIR /app                                                                                                                                                                0.0s
 => CACHED [linux/arm64 builder 7/8] RUN echo "Building for platform: linux/arm64"                                                                                                                               0.0s
 => [linux/arm64 builder 8/8] RUN xx-go --wrap && xx-go build -o /bin/hello ./main.go && xx-verify /bin/hello                                                                                                    9.1s
 => CACHED [linux/arm64 builder 3/8] COPY --from=tonistiigi/xx / /                                                                                                                                               0.0s
 => CACHED [linux/arm64 builder 4/8] ADD app /app                                                                                                                                                                0.0s
 => CACHED [linux/arm64->amd64 builder 5/8] RUN xx-apt install -y libc6-dev gcc                                                                                                                                  0.0s
 => CACHED [linux/arm64->amd64 builder 6/8] WORKDIR /app                                                                                                                                                         0.0s
 => CACHED [linux/arm64->amd64 builder 7/8] RUN echo "Building for platform: linux/amd64"                                                                                                                        0.0s
 => CACHED [linux/arm64->amd64 builder 8/8] RUN xx-go --wrap && xx-go build -o /bin/hello ./main.go && xx-verify /bin/hello                                                                                      0.0s
 => CACHED [linux/amd64 stage-2 2/3] COPY --from=builder /bin/hello /bin/hello                                                                                                                                   0.0s
 => CACHED [linux/amd64 stage-2 3/3] WORKDIR /app                                                                                                                                                                0.0s
 => CACHED [linux/arm64 stage-2 2/3] COPY --from=builder /bin/hello /bin/hello                                                                                                                                   0.0s
 => CACHED [linux/arm64 stage-2 3/3] WORKDIR /app                                                                                                                                                                0.0s
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
 => => pushing manifest for docker.io/grissomsh/go-multi-platform:latest@sha256:34ba25bbc06506f35f6ebbf7063f0f1c1107834c12aa554703cb62bb771dc57f                                                                 5.5s
 => [auth] grissomsh/go-multi-platform:pull,push token for registry-1.docker.io
```
可以访问[docker hub](https://hub.docker.com/repository/docker/grissomsh/go-multi-platform/general)查看镜像信息。

# 验证

如果在 x86 上运行 arm，会出现`exec format error`报错信息

```bash
docker run -it --platform linux/arm64  multi-platform /bin/bash
exec /bin/bash: exec format error
```