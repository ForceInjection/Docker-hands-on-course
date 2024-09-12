# Documentation
https://docs.docker.com/build/building/multi-stage/

# 构建（没有多步构建）

```bash
docker build -t hello .
```

# 多步构建

```bash
docker build -t hello . -f Dockerfile-multi-stages
```