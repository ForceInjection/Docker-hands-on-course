# Documentation
- [How to build docker images on Apple M-series](https://www.izumanetworks.com/blog/build-docker-on-apple-m/)
- [Faster Multi-Platform Builds: Dockerfile Cross-Compilation Guide](https://www.docker.com/blog/faster-multi-platform-builds-dockerfile-cross-compilation-guide/)
- [Multi-platform builds](https://docs.docker.com/build/building/multi-platform/)

# 安装 docker buildx

```bash
mkdir -p ~/.docker/cli-plugins/
curl -SL https://github.com/docker/buildx/releases/latest/download/docker-buildx-linux-amd64 -o ~/.docker/cli-plugins/docker-buildx
chmod +x ~/.docker/cli-plugins/docker-buildx
```

# 多平台构建

```bash
docker buildx build -f Dockerfile-multi-platform --platform linux/arm64 --tag multi-platform:latest --load .

# 同时多平台构建，需要使用 push
docker buildx build -f Dockerfile-multi-platform --platform linux/amd64,linux/arm64 --tag multi-platform:latest --push .
```

# 验证

```bash
# 如果在 x86 上运行 arm
docker run -it --platform linux/arm64  multi-platform /bin/bash
exec /bin/bash: exec format error
```