# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 项目概述

这是一个中文 Docker 动手教程仓库（"Docker 动手教程"），内容为按章节组织的学习文档 + 配套练习脚本。**没有构建/测试/打包体系** —— 主要内容是 Markdown 文档，附带可直接运行的 shell 脚本和 Dockerfile 示例。大多数新增工作本质是编写中文技术文档。

## 目录结构与学习路径

章节目录按学习顺序编号（01 → 05），每章一个独立目录，章节主页是各自的 `README.md`：

- `01-Docker-Introduction/` — Docker 基础概念与架构
- `02-Docker-Installation/` — 跨平台（macOS/Windows/Linux）安装配置
- `03-Pull-from-DockerHub-and-Run-Docker-Images/` — 镜像拉取与容器生命周期管理
- `04-Build-new-Docker-Image-and-Run-and-Push-to-DockerHub/` — Dockerfile 编写、镜像构建与推送（含 `Nginx-DockerFiles/` 实战）
- `04-2-Multi-Stage-Builds/` — 多阶段构建（`Dockerfile` 单阶段对比示例 / `Dockerfile-multi-stages` 为 golang:1.23 → scratch，演示 heredoc `COPY <<EOF` 语法；README 中镜像大小对比为实测数据）
- `04-3-Multi-Platform-Builds/` — buildx 多平台构建（tonistiigi/xx 交叉编译，`app/main.go` 是 Go 示例程序）
- `05-Essential-Docker-Commands/` — 命令大全 + 学习脚本工具
- `Advanced-Topics/` — 进阶专题文章（OCI 介绍、Docker 源码分析、Union Filesystem、containerd OverlayFS、Docker 中运行 GUI 程序），专题目录名用中文
- `PPT/Docker 动手教程/` — 教程幻灯片（HTML 分页页面 + `ppt-mode.js`）

根目录 `README.md` 是**导航型总索引**（学习路径 + 章节目录表 + FAQ），章节正文只在各章 README 维护，不要在总索引中复制正文内容；新增或改名章节时同步更新目录表。

## 常用命令

### 验证文档中的构建示例

```bash
# 04-2 多阶段构建（heredoc 语法需要 buildx / BuildKit，本机已装 docker-buildx 于 ~/.docker/cli-plugins/）
docker build -f Dockerfile-multi-stages -t multi-stage:latest .

# 04-3 多平台构建（需要 buildx 插件）
docker buildx build -f Dockerfile-multi-platform --platform linux/arm64 --tag multi-platform:latest --load .
```

### 练习脚本（05-Essential-Docker-Commands）

```bash
./docker-tools-launcher.sh          # 主启动脚本：图形化菜单，统一管理所有工具
./docker-tools-launcher.sh 1        # 直接运行指定工具
./docker-tools-launcher.sh status   # 工具状态检查
./docker-learning-scripts.sh        # 交互式命令学习
./docker-quick-reference.sh         # 命令速查
./docker-troubleshoot.sh            # 故障排查
./docker-auto-deploy.sh             # 自动部署
./docker-practice-lab.sh            # 练习实验
```

### Advanced-Topics/联合文件系统/scripts/

- `overlayfs_experiment.sh` — 手动挂载 OverlayFS，**需要 `sudo`**（root 权限）
- `docker_storage_benchmark.sh` — 存储驱动性能测试，依赖 `bc`
- `storage_monitor.py` — Flask 监控面板（输出到 `templates/dashboard.html`），依赖 Python 包：`pip install docker psutil flask`
- 其余 shell 脚本直接执行即可

## 编写约定

- **语言**：文档正文一律使用中文，代码块和命令保持英文
- **章节结构**：每章 README 遵循固定模板 —— 标题 + 引言 → 学习目标（📋）→ 正文（小标题配 emoji）→ 实践建议（💡）；章节开头常放 mermaid 学习路径图
- **表格**：命令对照表用 markdown 表格（命令 / 描述 / 示例 / 使用场景）格式
- **shell 脚本**：bash + `set -e`，脚本顶部定义统一的颜色输出函数（`print_info` / `print_success` / `print_warning` / `print_error`），正文通过它们输出
- **提交信息**：使用简短中文描述（如 "add union filesystem"、"update readme"）
