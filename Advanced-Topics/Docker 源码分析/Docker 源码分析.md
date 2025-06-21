# Docker 源码分析：docker run 命令执行流程

## 1. 目录

- [Docker 源码分析：docker run 命令执行流程](#docker-源码分析docker-run-命令执行流程)
  - [1. 目录](#1-目录)
  - [2. 概述](#2-概述)
  - [3. Docker 架构概览](#3-docker-架构概览)
  - [4. Docker CLI 层分析](#4-docker-cli-层分析)
    - [4.1 命令解析入口](#41-命令解析入口)
    - [4.2 运行逻辑处理](#42-运行逻辑处理)
    - [4.3 容器创建](#43-容器创建)
  - [5. Docker Daemon API 层分析](#5-docker-daemon-api-层分析)
    - [5.1 API 路由处理](#51-api-路由处理)
    - [8.2 容器创建 API 处理](#82-容器创建-api-处理)
    - [5.3 容器启动 API 处理](#53-容器启动-api-处理)
  - [6. Docker Daemon 层分析](#6-docker-daemon-层分析)
    - [6.1 容器创建处理](#61-容器创建处理)
    - [6.2 容器启动处理](#62-容器启动处理)
    - [6.3 OCI 规范生成](#63-oci-规范生成)
  - [7. containerd 层分析](#7-containerd-层分析)
    - [7.1 容器创建](#71-容器创建)
    - [7.2 任务创建和启动](#72-任务创建和启动)
  - [8. runc 层分析](#8-runc-层分析)
    - [8.1 容器运行时入口](#81-容器运行时入口)
    - [5.2 容器创建](#52-容器创建)
    - [8.3 容器启动和执行](#83-容器启动和执行)
  - [6. Linux 进程隔离技术详解](#6-linux-进程隔离技术详解)
    - [6.1 Namespace 命名空间隔离](#61-namespace-命名空间隔离)
      - [6.1.1 PID Namespace (进程隔离)](#611-pid-namespace-进程隔离)
      - [6.1.2 Network Namespace (网络隔离)](#612-network-namespace-网络隔离)
      - [6.1.3 Mount Namespace (文件系统隔离)](#613-mount-namespace-文件系统隔离)
      - [6.1.4 IPC Namespace (进程间通信隔离)](#614-ipc-namespace-进程间通信隔离)
      - [6.1.5 UTS Namespace (主机名隔离)](#615-uts-namespace-主机名隔离)
      - [6.1.6 User Namespace (用户隔离)](#616-user-namespace-用户隔离)
    - [6.2 Cgroups 资源控制](#62-cgroups-资源控制)
      - [6.2.1 CPU 资源控制](#621-cpu-资源控制)
      - [6.2.2 内存资源控制](#622-内存资源控制)
      - [6.2.3 块设备 I/O 控制](#623-块设备-io-控制)
      - [6.2.4 网络资源控制](#624-网络资源控制)
    - [6.3 runc 中的系统调用实现](#63-runc-中的系统调用实现)
      - [6.3.1 创建命名空间](#631-创建命名空间)
      - [6.3.2 设置 Cgroups](#632-设置-cgroups)
    - [6.4 进程创建和执行流程](#64-进程创建和执行流程)
      - [6.4.1 完整的进程创建流程](#641-完整的进程创建流程)
      - [6.4.2 命名空间和 Cgroups 的协同工作](#642-命名空间和-cgroups-的协同工作)
    - [6.5 监控和调试](#65-监控和调试)
      - [6.5.1 查看容器的命名空间](#651-查看容器的命名空间)
      - [6.5.2 查看容器的 Cgroups 设置](#652-查看容器的-cgroups-设置)
      - [6.5.3 实时监控资源使用](#653-实时监控资源使用)
  - [7. 完整执行流程总结](#7-完整执行流程总结)
    - [7.1 调用链路图](#71-调用链路图)
    - [7.2 关键数据结构转换](#72-关键数据结构转换)
    - [7.3 核心技术点](#73-核心技术点)
  - [8. 源码版本说明](#8-源码版本说明)
  - [9. 总结](#9-总结)

## 2. 概述

本文基于 Docker 最新版本的源码，深入分析 `docker run` 命令从 Docker CLI 到 runc 的完整执行流程。我们将追踪代码执行路径，理解 Docker 架构中各个组件的协作机制。

## 3. Docker 架构概览

在深入源码分析之前，让我们先了解 Docker 的整体架构：

```text
┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│ Docker CLI  │───▶│Docker Daemon│───▶│ containerd  │───▶│    runc     │
└─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘
      客户端          Docker守护进程      容器运行时管理器     容器运行时
```

## 4. Docker CLI 层分析

### 4.1 命令解析入口

当用户执行 `docker run` 命令时，首先进入 Docker CLI 的处理流程。

**文件位置**: [`cli/command/container/run.go`](https://github.com/docker/cli/blob/master/cli/command/container/run.go)

```go
// NewRunCommand create a new `docker run` command
func NewRunCommand(dockerCli command.Cli) *cobra.Command {
    var options runOptions
    var copts *containerOptions

    cmd := &cobra.Command{
        Use:   "run [OPTIONS] IMAGE [COMMAND] [ARG...]",
        Short: "Create and run a new container from an image",
        Args:  cli.RequiresMinArgs(1),
        RunE: func(cmd *cobra.Command, args []string) error {
            copts.Image = args[0]
            if len(args) > 1 {
                copts.Args = args[1:]
            }
            return runRun(cmd.Context(), dockerCli, cmd.Flags(), &options, copts)
        },
        ValidArgsFunction: completion.ImageNames(dockerCli, 1),
        Annotations: map[string]string{
            "category-top": "1",
            "aliases":      "docker container run, docker run",
        },
    }
    // ... 参数解析和标志设置
    return cmd
}
```

### 4.2 运行逻辑处理

**文件位置**: [`cli/command/container/run.go`](https://github.com/docker/cli/blob/master/cli/command/container/run.go)

```go
func runRun(ctx context.Context, dockerCli command.Cli, flags *pflag.FlagSet, 
           ropts *runOptions, copts *containerOptions) error {
    // 1. 验证拉取选项
    if err := validatePullOpt(ropts.pull); err != nil {
        return cli.StatusError{
            Status:     withHelp(err, "run").Error(),
            StatusCode: 125,
        }
    }
    
    // 2. 处理代理配置
    proxyConfig := dockerCli.ConfigFile().ParseProxyConfig(
        dockerCli.Client().DaemonHost(), 
        opts.ConvertKVStringsToMapWithNil(copts.env.GetSlice()))
    
    // 3. 创建容器配置
    containerConfig, err := parse(flags, copts, dockerCli.ServerInfo().OSType)
    if err != nil {
        return cli.StatusError{
            Status:     withHelp(err, "run").Error(),
            StatusCode: 125,
        }
    }
    
    // 4. 调用容器创建和启动逻辑
    return runContainer(ctx, dockerCli, ropts, copts, containerConfig)
}
```

### 4.3 容器创建

**文件位置**: [`cli/command/container/create.go`](https://github.com/docker/cli/blob/master/cli/command/container/create.go)

```go
func runCreate(cmd *cobra.Command, args []string) error {
    containerConfig, err := parse(flags, args, dockerCli.ServerInfo().OSType)
    if err != nil {
        return err
    }

    // 调用 Docker API 创建容器
    response, err := dockerCli.Client().ContainerCreate(
        context.Background(),
        containerConfig.Config,
        containerConfig.HostConfig,
        containerConfig.NetworkingConfig,
        containerConfig.Platform,
        containerConfig.ContainerName,
    )
    if err != nil {
        return err
    }

    fmt.Fprintln(dockerCli.Out(), response.ID)
    return nil
}
```

## 5. Docker Daemon API 层分析

### 5.1 API 路由处理

**文件位置**: [`api/server/router/container/container.go`](https://github.com/moby/moby/blob/master/api/server/router/container/container.go)

```go
// containerRouter is a router to talk with the container controller
type containerRouter struct {
    backend Backend
    decoder httputils.ContainerDecoder
    routes  []router.Route
    cgroup2 bool
}

// NewRouter initializes a new container router
func NewRouter(b Backend, decoder httputils.ContainerDecoder, cgroup2 bool) router.Router {
    r := &containerRouter{
        backend: b,
        decoder: decoder,
        cgroup2: cgroup2,
    }
    r.initRoutes()
    return r
}

// Routes returns the available routes to the container controller
func (r *containerRouter) Routes() []router.Route {
    return r.routes
}

// initRoutes initializes the routes array
func (r *containerRouter) initRoutes() {
    r.routes = []router.Route{
        // POST /containers/create
        router.NewPostRoute("/containers/create", r.postContainersCreate),
        // POST /containers/{name:.*}/start
        router.NewPostRoute("/containers/{name:.*}/start", r.postContainersStart),
        // ... 其他路由
    }
}
```

### 8.2 容器创建 API 处理

**文件位置**: [`api/server/router/container/container_routes.go`](https://github.com/moby/moby/blob/main/api/server/router/container/container_routes.go)

```go
func (c *containerRouter) postContainersCreate(ctx context.Context, w http.ResponseWriter, r *http.Request, vars map[string]string) error {
    // 1. 解析请求参数
    if err := httputils.ParseForm(r); err != nil {
        return err
    }
    if err := httputils.CheckForJSON(r); err != nil {
        return err
    }
    
    name := r.Form.Get("name")
    
    // 2. 解码配置
    config, hostConfig, networkingConfig, err := s.decoder.DecodeConfig(r.Body)
    if err != nil {
        return err
    }
    
    // 3. 验证和设置默认配置
    if config == nil {
        return errdefs.InvalidParameter(runconfig.ErrEmptyConfig)
    }
    if hostConfig == nil {
        hostConfig = &container.HostConfig{}
    }
    if networkingConfig == nil {
        networkingConfig = &network.NetworkingConfig{}
    }

    // 4. 调用 daemon 创建容器
    ccr, err := s.backend.ContainerCreate(ctx, types.ContainerCreateConfig{
        Name:             name,
        Config:           config,
        HostConfig:       hostConfig,
        NetworkingConfig: networkingConfig,
    })

    if err != nil {
        return err
    }

    // 5. 返回创建结果
    return httputils.WriteJSON(w, http.StatusCreated, ccr)
}
```

### 5.3 容器启动 API 处理

**文件位置**: `api/server/router/container/container.go`

```go
func (s *containerRouter) postContainersStart(ctx context.Context, w http.ResponseWriter, r *http.Request, vars map[string]string) error {
    // 1. 开启追踪
    ctx, span := otel.Tracer("").Start(ctx, "containerRouter.postContainersStart")
    defer span.End()
    
    // 2. 验证请求体（API v1.24+ 不允许非空请求体）
    if r.ContentLength > 7 || r.ContentLength == -1 {
        return errdefs.InvalidParameter(errors.New("starting container with non-empty request body was deprecated since API v1.22 and removed in v1.24"))
    }
    
    // 3. 解析请求参数
    if err := httputils.ParseForm(r); err != nil {
        return err
    }
    
    // 4. 调用后端启动容器（支持检查点功能）
    if err := s.backend.ContainerStart(ctx, vars["name"], 
                                      r.Form.Get("checkpoint"), 
                                      r.Form.Get("checkpoint-dir")); err != nil {
        return err
    }
    
    // 5. 返回成功响应
    w.WriteHeader(http.StatusNoContent)
    return nil
}
```

## 6. Docker Daemon 层分析

### 6.1 容器创建处理

**文件位置**: [`daemon/create.go`](https://github.com/moby/moby/blob/main/daemon/create.go)

```go
// ContainerCreateIgnoreImagesArgsEscaped creates a new container without honoring images ArgsEscaped option.
// This is called from the builder RUN case
// and ensures that we do not take the images ArgsEscaped
func (daemon *Daemon) ContainerCreateIgnoreImagesArgsEscaped(ctx context.Context, params backend.ContainerCreateConfig) (containertypes.CreateResponse, error) {
    return daemon.containerCreate(ctx, daemon.config(), createOpts{
        params:                  params,
        ignoreImagesArgsEscaped: true,
    })
}

func (daemon *Daemon) containerCreate(ctx context.Context, daemonCfg *configStore, opts createOpts) (_ containertypes.CreateResponse, retErr error) {
    ctx, span := otel.Tracer("").Start(ctx, "daemon.containerCreate", trace.WithAttributes(
        labelsAsOTelAttributes(opts.params.Config.Labels)...,
    ))
    defer func() {
        otelutil.RecordStatus(span, retErr)
        span.End()
    }()
    
    // 1. 验证网络配置
    err := daemon.validateNetworkingConfig(opts.params.NetworkingConfig)
    if err != nil {
        return containertypes.CreateResponse{Warnings: warnings}, errdefs.InvalidParameter(err)
    }
    
    // 2. 设置默认 HostConfig
    if opts.params.HostConfig == nil {
        opts.params.HostConfig = &containertypes.HostConfig{}
    }
    
    // 3. 调整容器设置
    err = daemon.adaptContainerSettings(&daemonCfg.Config, opts.params.HostConfig)
    if err != nil {
        return containertypes.CreateResponse{Warnings: warnings}, errdefs.InvalidParameter(err)
    }

    // 5. 注册容器到 daemon
    daemon.Register(container)
    
    return container, nil
}
```

### 6.2 容器启动处理

**文件位置**: [`daemon/start.go`](https://github.com/moby/moby/blob/main/daemon/start.go)

```go
func (daemon *Daemon) ContainerStart(ctx context.Context, name string, checkpoint string, checkpointDir string) error {
    // 1. 获取配置
    daemonCfg := daemon.config()
    
    // 2. 验证检查点功能
    if checkpoint != "" && !daemonCfg.Experimental {
        return errdefs.InvalidParameter(errors.New("checkpoint is only supported in experimental mode"))
    }
    
    // 3. 获取容器
    ctr, err := daemon.GetContainer(name)
    if err != nil {
        return err
    }
    
    // 4. 验证容器状态
    validateState := func() error {
        ctr.Lock()
        defer ctr.Unlock()
        
        if ctr.Paused {
            return errdefs.Conflict(errors.New("cannot start a paused container, try unpause instead"))
        }
        
        if ctr.Running {
            return errdefs.NotModified(errors.New("container is already running"))
        }
        
        if ctr.RemovalInProgress || ctr.Dead {
            return errdefs.Conflict(errors.New("container is marked for removal and cannot be started"))
        }
        
        return nil
    }
    
    if err := validateState(); err != nil {
        return err
    }
    
    // 5. 启动容器
    return daemon.containerStart(ctx, daemonCfg, ctr, checkpoint, checkpointDir, true)
}

func (daemon *Daemon) containerStart(container *container.Container, checkpoint string, checkpointDir string, resetRestartManager bool) (err error) {
    // 1. 设置容器状态
    container.Lock()
    defer container.Unlock()

    if container.Running {
        return nil
    }

    // 2. 创建容器运行时规范
    spec, err := daemon.createSpec(container)
    if err != nil {
        return err
    }

    // 3. 调用 containerd 启动容器
    if err := daemon.containerd.Create(context.Background(), container.ID, spec, runtimeOptions); err != nil {
        return err
    }

    // 4. 启动容器进程
    pid, err := daemon.containerd.Start(context.Background(), container.ID, checkpointDir, withStdin, attachStdio)
    if err != nil {
        return err
    }

    container.SetRunning(pid, true)
    return nil
}
```

### 6.3 OCI 规范生成

**文件位置**: [`daemon/oci_linux.go`](https://github.com/moby/moby/blob/main/daemon/oci_linux.go)

```go
func (daemon *Daemon) createSpec(c *container.Container) (*specs.Spec, error) {
    s := oci.DefaultSpec()

    // 1. 设置进程配置
    if err := setProcess(s, c); err != nil {
        return nil, err
    }

    // 2. 设置根文件系统
    if err := setRootfs(s, c); err != nil {
        return nil, err
    }

    // 3. 设置挂载点
    if err := setMounts(daemon, s, c); err != nil {
        return nil, err
    }

    // 4. 设置网络命名空间
    if err := setNamespaces(daemon, s, c); err != nil {
        return nil, err
    }

    // 5. 设置 cgroups
    if err := setResources(s, c.HostConfig.Resources); err != nil {
        return nil, err
    }

    // 6. 设置安全配置
    if err := setSeccomp(daemon, s, c); err != nil {
        return nil, err
    }

    return s, nil
}
```

## 7. containerd 层分析

### 7.1 容器创建

**文件位置**: [`client.go`](https://github.com/containerd/containerd/blob/main/client.go)

```go
func (c *Client) NewContainer(ctx context.Context, id string, opts ...NewContainerOpts) (Container, error) {
    // 1. 创建容器请求
    r := &containers.CreateContainerRequest{
        Container: containers.Container{
            ID: id,
        },
    }

    // 2. 应用选项
    for _, o := range opts {
        if err := o(ctx, c, &r.Container); err != nil {
            return nil, err
        }
    }

    // 3. 调用 containerd API 创建容器
    response, err := c.ContainerService().Create(ctx, r)
    if err != nil {
        return nil, err
    }

    return containerFromRecord(c, response.Container), nil
}
```

### 7.2 任务创建和启动

**文件位置**: [`task.go`](https://github.com/containerd/containerd/blob/main/task.go)

```go
func (c *container) NewTask(ctx context.Context, ioCreation cio.Creation, opts ...NewTaskOpts) (_ Task, err error) {
    // 1. 创建 IO
    i, err := ioCreation(c.id)
    if err != nil {
        return nil, err
    }

    // 2. 创建任务请求
    request := &tasks.CreateTaskRequest{
        ContainerID: c.id,
        Terminal:    i.Terminal,
        Stdin:       i.Stdin,
        Stdout:      i.Stdout,
        Stderr:      i.Stderr,
    }

    // 3. 应用选项
    for _, o := range opts {
        if err := o(ctx, c.client, &request); err != nil {
            return nil, err
        }
    }

    // 4. 调用 containerd 创建任务
    response, err := c.client.TaskService().Create(ctx, request)
    if err != nil {
        return nil, err
    }

    return &task{
        client: c.client,
        io:     i,
        id:     response.ContainerID,
        pid:    response.Pid,
    }, nil
}

func (t *task) Start(ctx context.Context) error {
    // 启动任务
    _, err := t.client.TaskService().Start(ctx, &tasks.StartRequest{
        ContainerID: t.id,
    })
    return err
}
```

## 8. runc 层分析

### 8.1 容器运行时入口

**文件位置**: [`main.go`](https://github.com/opencontainers/runc/blob/main/main.go)

```go
func main() {
    app := cli.NewApp()
    app.Name = "runc"
    app.Usage = usage
    
    // 设置版本信息
    v := []string{version}
    if gitCommit != "" {
        v = append(v, "commit: "+gitCommit)
    }
    v = append(v, "spec: "+specs.Version)
    v = append(v, "go: "+runtime.Version())
    
    major, minor, micro := seccomp.Version()
    if major+minor+micro > 0 {
        v = append(v, fmt.Sprintf("libseccomp: %d.%d.%d", major, minor, micro))
    }
    app.Version = strings.Join(v, "\n")
    
    // 设置根目录
    root := "/run/runc"
    xdgDirUsed := false
    xdgRuntimeDir := os.Getenv("XDG_RUNTIME_DIR")
    if xdgRuntimeDir != "" && shouldHonorXDGRuntimeDir() {
        root = xdgRuntimeDir + "/runc"
        xdgDirUsed = true
    }
    
    app.Flags = []cli.Flag{
        cli.BoolFlag{
            Name:  "debug",
            Usage: "enable debug output for logging",
        },
        cli.StringFlag{
            Name:  "log",
            Value: "/dev/null",
            Usage: "set the log file path where internal debug information is written",
        },
        cli.StringFlag{
            Name:  "log-format",
            Value: "text",
            Usage: "set the format used by logs ('text' (default), or 'json')",
        },
        cli.StringFlag{
            Name:  "root",
            Value: root,
            Usage: "root directory for storage of container state (this should be located in tmpfs)",
        },
        cli.StringFlag{
            Name:  "criu",
            Value: "criu",
            Usage: "path to the criu binary used for checkpoint and restore",
        },
        cli.BoolFlag{
            Name:  "systemd-cgroup",
            Usage: "enable systemd cgroup support, expects cgroupsPath to be of form \"slice:prefix:name\" for e.g. \"system.slice:runc:434234\"",
        },
        cli.StringFlag{
            Name:  "rootless",
            Value: "auto",
            Usage: "ignore cgroup permission errors ('true', 'false', or 'auto')",
        },
    }
    
    app.Commands = []cli.Command{
        checkpointCommand,
        createCommand,
        deleteCommand,
        eventsCommand,
        execCommand,
        initCommand,
        killCommand,
        listCommand,
        pauseCommand,
        psCommand,
        restoreCommand,
        resumeCommand,
        runCommand,
        specCommand,
        startCommand,
        stateCommand,
        updateCommand,
        featuresCommand,
    }
    
    app.Before = func(context *cli.Context) error {
        if err := configLogrus(context); err != nil {
            return err
        }
        if path := context.GlobalString("root"); path != "" {
            if abs, err := filepath.Abs(path); err == nil {
                // do nothing
            } else {
                logrus.Fatal(err)
            }
        }
        return nil
    }
    
    // 设置错误输出
    cli.ErrWriter = &FatalWriter{cli.ErrWriter}
    if err := app.Run(os.Args); err != nil {
        fatal(err)
    }
}
```

### 5.2 容器创建

**文件位置**: [`create.go`](https://github.com/opencontainers/runc/blob/main/create.go)

```go
var createCommand = cli.Command{
    Name:  "create",
    Usage: "create a container",
    ArgsUsage: `<container-id>

Where "<container-id>" is your name for the instance of the container that you
are starting. The name you provide for the container instance must be unique on
your host.`,
    Description: `The create command creates an instance of a container for a bundle. The bundle
is a directory with a specification file named "` + specConfig + `" and a root
filesystem.

The specification file includes an args parameter. The args parameter is used
to specify command(s) that get executed when the container is started.
To change the command(s) that get executed on start, edit the args parameter of
the spec. See "runc spec --help" for more explanation.`,
    Flags: []cli.Flag{
        cli.StringFlag{
            Name:  "bundle, b",
            Value: "",
            Usage: `path to the root of the bundle directory, defaults to the current directory`,
        },
        cli.StringFlag{
            Name:  "console-socket",
            Value: "",
            Usage: "path to an AF_UNIX socket which will receive a file descriptor referencing the master end of the console's pseudoterminal",
        },
        cli.StringFlag{
            Name:  "pidfd-socket",
            Usage: "path to an AF_UNIX socket which will receive a file descriptor referencing the init process",
        },
        cli.StringFlag{
            Name:  "pid-file",
            Value: "",
            Usage: "specify the file to write the process id to",
        },
        cli.BoolFlag{
            Name:  "no-pivot",
            Usage: "do not use pivot root to jail process inside rootfs. This will cause the container to inherit the calling processes session key",
        },
        cli.IntFlag{
            Name:  "preserve-fds",
            Usage: "Pass N additional file descriptors to the container (stdio + $LISTEN_FDS + N in total)",
        },
    },
    Action: func(context *cli.Context) error {
        if err := checkArgs(context, 1, exactArgs); err != nil {
            return err
        }
        status, err := startContainer(context, CT_ACT_CREATE, nil)
        if err == nil {
            // exit with the container's exit status so any external supervisor
            // is notified of the exit with the correct exit status.
            os.Exit(status)
        }
        return fmt.Errorf("runc create failed: %w", err)
    },
}
```

### 8.3 容器启动和执行

**文件位置**: [`utils_linux.go`](https://github.com/opencontainers/runc/blob/main/utils_linux.go)

```go
func startContainer(context *cli.Context, action CtAct, criuOpts *libcontainer.CriuOpts) (int, error) {
    if err := revisePidFile(context); err != nil {
        return -1, err
    }
    
    // 1. 加载容器配置
    spec, err := setupSpec(context)
    if err != nil {
        return -1, err
    }
    
    // 2. 获取容器 ID
    id := context.Args().First()
    if id == "" {
        return -1, errEmptyID
    }
    
    // 3. 创建或加载容器
    container, err := createContainer(context, id, spec)
    if err != nil {
        return -1, err
    }
    
    // 4. 设置通知套接字
    notifySocket := newNotifySocket(context, os.Getenv("NOTIFY_SOCKET"), id)
    if notifySocket != nil {
        if err := notifySocket.setupSpec(context, spec); err != nil {
            return -1, err
        }
    }
    
    // 5. 创建运行器
    listenFDs := []*os.File{}
    if os.Getenv("LISTEN_FDS") != "" {
        listenFDs = activation.Files(false)
    }
    
    r := &runner{
        enableSubreaper: !context.Bool("no-subreaper"),
        shouldDestroy:   !context.Bool("keep"),
        container:       container,
        listenFDs:       listenFDs,
        notifySocket:    notifySocket,
        consoleSocket:   context.String("console-socket"),
        pidfdSocket:     context.String("pidfd-socket"),
        detach:          context.Bool("detach"),
        pidFile:         context.String("pid-file"),
        preserveFDs:     context.Int("preserve-fds"),
        action:          action,
        criuOpts:        criuOpts,
        init:            true,
    }
    
    // 6. 运行容器
    return r.run(spec.Process)
}

func (r *runner) run(config *specs.Process) (int, error) {
    // 1. 验证配置
    if err := r.checkTerminal(config); err != nil {
        return -1, err
    }
    
    // 2. 创建进程
    process, err := newProcess(*config)
    if err != nil {
        return -1, err
    }
    
    // 3. 设置 IO
    if err := r.setupIO(process, rootuid, rootgid, config.Terminal, r.detach, r.consoleSocket); err != nil {
        return -1, err
    }
    
    // 4. 启动容器
    switch r.action {
    case CT_ACT_CREATE:
        err = r.container.Start(process)
    case CT_ACT_RESTORE:
        err = r.container.Restore(process, r.criuOpts)
    case CT_ACT_RUN:
        err = r.container.Run(process)
    default:
        panic("Unknown action")
    }
    
    if err != nil {
        r.destroy()
        return -1, err
    }
    
    // 5. 等待进程完成
    if r.detach {
        return 0, nil
    }
    
    return r.wait(process)
}
```

## 6. Linux 进程隔离技术详解

### 6.1 Namespace 命名空间隔离

Namespace 是 Linux 内核提供的一种进程隔离机制，Docker 利用多种 namespace 来实现容器的隔离。

#### 6.1.1 PID Namespace (进程隔离)

**作用**: 隔离进程 ID 空间，容器内的进程看到的 PID 从 1 开始。

**实现位置**: [`daemon/oci_linux.go`](https://github.com/moby/moby/blob/main/daemon/oci_linux.go)

```go
func setNamespaces(daemon *Daemon, s *specs.Spec, c *container.Container) error {
    // PID namespace 设置
    if c.HostConfig.PidMode.IsContainer() {
        ns := specs.LinuxNamespace{
            Type: specs.PIDNamespace,
        }
        setNamespace(s, ns)
    } else if !c.HostConfig.PidMode.IsHost() {
        ns := specs.LinuxNamespace{
            Type: specs.PIDNamespace,
        }
        setNamespace(s, ns)
    }
    return nil
}
```

**系统调用**: `clone(CLONE_NEWPID)` 或 `unshare(CLONE_NEWPID)`

**效果**:

- 容器内第一个进程的 PID 为 1
- 容器内进程无法看到宿主机的其他进程
- 容器内的进程树独立于宿主机

#### 6.1.2 Network Namespace (网络隔离)

**作用**: 隔离网络设备、IP 地址、端口、路由表等网络资源。

```go
func setNetworkNamespace(s *specs.Spec, c *container.Container) error {
    if c.HostConfig.NetworkMode.IsHost() {
        // 使用宿主机网络
        return nil
    }
    
    // 创建独立的网络命名空间
    ns := specs.LinuxNamespace{
        Type: specs.NetworkNamespace,
    }
    setNamespace(s, ns)
    return nil
}
```

**系统调用**: `clone(CLONE_NEWNET)` 或 `unshare(CLONE_NEWNET)`

**效果**:

- 容器拥有独立的网络接口
- 独立的 IP 地址和端口空间
- 独立的路由表和防火墙规则

#### 6.1.3 Mount Namespace (文件系统隔离)

**作用**: 隔离文件系统挂载点，容器内的挂载操作不影响宿主机。

```go
func setMountNamespace(s *specs.Spec) error {
    ns := specs.LinuxNamespace{
        Type: specs.MountNamespace,
    }
    setNamespace(s, ns)
    return nil
}
```

**系统调用**: `clone(CLONE_NEWNS)` 或 `unshare(CLONE_NEWNS)`

**效果**:

- 容器拥有独立的文件系统视图
- 容器内的挂载操作不影响宿主机
- 支持 OverlayFS 等联合文件系统

#### 6.1.4 IPC Namespace (进程间通信隔离)

**作用**: 隔离 System V IPC 和 POSIX 消息队列。

```go
func setIPCNamespace(s *specs.Spec, c *container.Container) error {
    if c.HostConfig.IpcMode.IsHost() {
        return nil
    }
    
    ns := specs.LinuxNamespace{
        Type: specs.IPCNamespace,
    }
    setNamespace(s, ns)
    return nil
}
```

**系统调用**: `clone(CLONE_NEWIPC)` 或 `unshare(CLONE_NEWIPC)`

#### 6.1.5 UTS Namespace (主机名隔离)

**作用**: 隔离主机名和域名。

```go
func setUTSNamespace(s *specs.Spec) error {
    ns := specs.LinuxNamespace{
        Type: specs.UTSNamespace,
    }
    setNamespace(s, ns)
    return nil
}
```

**系统调用**: `clone(CLONE_NEWUTS)` 或 `unshare(CLONE_NEWUTS)`

#### 6.1.6 User Namespace (用户隔离)

**作用**: 隔离用户 ID 和组 ID，实现非特权容器。

```go
func setUserNamespace(s *specs.Spec, c *container.Container) error {
    if !c.HostConfig.UsernsMode.IsHost() {
        ns := specs.LinuxNamespace{
            Type: specs.UserNamespace,
        }
        setNamespace(s, ns)
        
        // 设置 UID/GID 映射
        s.Linux.UIDMappings = []specs.LinuxIDMapping{
            {
                ContainerID: 0,
                HostID:      100000,
                Size:        65536,
            },
        }
        s.Linux.GIDMappings = []specs.LinuxIDMapping{
            {
                ContainerID: 0,
                HostID:      100000,
                Size:        65536,
            },
        }
    }
    return nil
}
```

**系统调用**: `clone(CLONE_NEWUSER)` 或 `unshare(CLONE_NEWUSER)`

### 6.2 Cgroups 资源控制

Cgroups (Control Groups) 是 Linux 内核提供的资源管理机制，Docker 使用它来限制和监控容器的资源使用。

#### 6.2.1 CPU 资源控制

**实现位置**: [`daemon/oci_linux.go`](https://github.com/moby/moby/blob/main/daemon/oci_linux.go)

```go
func setCPUResources(s *specs.Spec, r *containertypes.Resources) error {
    if s.Linux.Resources == nil {
        s.Linux.Resources = &specs.LinuxResources{}
    }
    if s.Linux.Resources.CPU == nil {
        s.Linux.Resources.CPU = &specs.LinuxCPU{}
    }
    
    cpu := s.Linux.Resources.CPU
    
    // CPU 份额 (相对权重)
    if r.CPUShares != 0 {
        shares := uint64(r.CPUShares)
        cpu.Shares = &shares
    }
    
    // CPU 周期和配额 (绝对限制)
    if r.CPUPeriod != 0 {
        period := uint64(r.CPUPeriod)
        cpu.Period = &period
    }
    if r.CPUQuota != 0 {
        quota := r.CPUQuota
        cpu.Quota = &quota
    }
    
    // CPU 亲和性
    if r.CpusetCpus != "" {
        cpu.Cpus = r.CpusetCpus
    }
    if r.CpusetMems != "" {
        cpu.Mems = r.CpusetMems
    }
    
    return nil
}
```

**Cgroups 文件系统路径**:

- `/sys/fs/cgroup/cpu/docker/<container_id>/cpu.shares` - CPU 份额
- `/sys/fs/cgroup/cpu/docker/<container_id>/cpu.cfs_period_us` - CPU 周期
- `/sys/fs/cgroup/cpu/docker/<container_id>/cpu.cfs_quota_us` - CPU 配额
- `/sys/fs/cgroup/cpuset/docker/<container_id>/cpuset.cpus` - CPU 亲和性

#### 6.2.2 内存资源控制

```go
func setMemoryResources(s *specs.Spec, r *containertypes.Resources) error {
    if s.Linux.Resources == nil {
        s.Linux.Resources = &specs.LinuxResources{}
    }
    if s.Linux.Resources.Memory == nil {
        s.Linux.Resources.Memory = &specs.LinuxMemory{}
    }
    
    memory := s.Linux.Resources.Memory
    
    // 内存限制
    if r.Memory != 0 {
        limit := r.Memory
        memory.Limit = &limit
    }
    
    // 内存预留
    if r.MemoryReservation != 0 {
        reservation := r.MemoryReservation
        memory.Reservation = &reservation
    }
    
    // Swap 限制
    if r.MemorySwap > 0 {
        swap := r.MemorySwap
        memory.Swap = &swap
    }
    
    // 内存交换性
    if r.MemorySwappiness != nil {
        swappiness := uint64(*r.MemorySwappiness)
        memory.Swappiness = &swappiness
    }
    
    // OOM Killer 控制
    if r.OomKillDisable != nil {
        memory.DisableOOMKiller = r.OomKillDisable
    }
    
    return nil
}
```

**Cgroups 文件系统路径**:

- `/sys/fs/cgroup/memory/docker/<container_id>/memory.limit_in_bytes` - 内存限制
- `/sys/fs/cgroup/memory/docker/<container_id>/memory.soft_limit_in_bytes` - 内存软限制
- `/sys/fs/cgroup/memory/docker/<container_id>/memory.memsw.limit_in_bytes` - 内存+Swap 限制
- `/sys/fs/cgroup/memory/docker/<container_id>/memory.oom_control` - OOM 控制

#### 6.2.3 块设备 I/O 控制

```go
func setBlkioResources(s *specs.Spec, r *containertypes.Resources) error {
    if s.Linux.Resources == nil {
        s.Linux.Resources = &specs.LinuxResources{}
    }
    if s.Linux.Resources.BlockIO == nil {
        s.Linux.Resources.BlockIO = &specs.LinuxBlockIO{}
    }
    
    blkio := s.Linux.Resources.BlockIO
    
    // I/O 权重
    if r.BlkioWeight != 0 {
        weight := uint16(r.BlkioWeight)
        blkio.Weight = &weight
    }
    
    // 设备读写速率限制
    if len(r.BlkioDeviceReadBps) > 0 {
        for _, throttle := range r.BlkioDeviceReadBps {
            blkio.ThrottleReadBpsDevice = append(blkio.ThrottleReadBpsDevice, specs.LinuxThrottleDevice{
                Rate:  uint64(throttle.Rate),
                Major: throttle.Major,
                Minor: throttle.Minor,
            })
        }
    }
    
    if len(r.BlkioDeviceWriteBps) > 0 {
        for _, throttle := range r.BlkioDeviceWriteBps {
            blkio.ThrottleWriteBpsDevice = append(blkio.ThrottleWriteBpsDevice, specs.LinuxThrottleDevice{
                Rate:  uint64(throttle.Rate),
                Major: throttle.Major,
                Minor: throttle.Minor,
            })
        }
    }
    
    return nil
}
```

**Cgroups 文件系统路径**:

- `/sys/fs/cgroup/blkio/docker/<container_id>/blkio.weight` - I/O 权重
- `/sys/fs/cgroup/blkio/docker/<container_id>/blkio.throttle.read_bps_device` - 读取速率限制
- `/sys/fs/cgroup/blkio/docker/<container_id>/blkio.throttle.write_bps_device` - 写入速率限制

#### 6.2.4 网络资源控制

```go
func setNetworkResources(s *specs.Spec, r *containertypes.Resources) error {
    if s.Linux.Resources == nil {
        s.Linux.Resources = &specs.LinuxResources{}
    }
    if s.Linux.Resources.Network == nil {
        s.Linux.Resources.Network = &specs.LinuxNetwork{}
    }
    
    network := s.Linux.Resources.Network
    
    // 网络类别 ID
    if r.NetClsClassid != 0 {
        classID := uint32(r.NetClsClassid)
        network.ClassID = &classID
    }
    
    // 网络优先级
    if len(r.NetPrioIfpriomap) > 0 {
        for _, prio := range r.NetPrioIfpriomap {
            network.Priorities = append(network.Priorities, specs.LinuxInterfacePriority{
                Name:     prio.Interface,
                Priority: uint32(prio.Priority),
            })
        }
    }
    
    return nil
}
```

### 6.3 runc 中的系统调用实现

#### 6.3.1 创建命名空间

**文件位置**: [`libcontainer/nsenter/nsexec.c`](https://github.com/opencontainers/runc/blob/main/libcontainer/nsenter/nsexec.c)

```c
// 创建新的命名空间
static int clone_parent(jmp_buf *env, int jmpval) {
    struct clone_t ca = {
        .env = env,
        .jmpval = jmpval,
    };
    
    // 使用 clone 系统调用创建新进程和命名空间
    return clone(child_func, ca.stack_ptr, 
                 CLONE_PARENT | CLONE_NEWPID | CLONE_NEWNS | 
                 CLONE_NEWNET | CLONE_NEWIPC | CLONE_NEWUTS | 
                 CLONE_NEWUSER | SIGCHLD, &ca);
}

// 加入现有命名空间
static int join_namespaces(char *nslist[]) {
    int i, fd;
    
    for (i = 0; nslist[i]; i++) {
        fd = open(nslist[i], O_RDONLY);
        if (fd == -1) {
            return -1;
        }
        
        // 使用 setns 系统调用加入命名空间
        if (setns(fd, 0) == -1) {
            close(fd);
            return -1;
        }
        close(fd);
    }
    
    return 0;
}
```

#### 6.3.2 设置 Cgroups

**文件位置**: [`libcontainer/cgroups/fs/apply_raw.go`](https://github.com/opencontainers/runc/blob/main/libcontainer/cgroups/fs/apply_raw.go)

```go
func (m *manager) Apply(pid int) error {
    // 创建 cgroup 目录
    if err := m.createCgroupPath(); err != nil {
        return err
    }
    
    // 将进程 PID 写入 cgroup.procs 文件
    for _, sys := range m.subsystems {
        path, err := m.path(sys.Name())
        if err != nil {
            return err
        }
        
        if err := writeFile(path, "cgroup.procs", strconv.Itoa(pid)); err != nil {
            return err
        }
    }
    
    return nil
}

func (m *manager) Set(container *configs.Config) error {
    // 设置 CPU 资源限制
    if container.Cgroups.Resources.CpuShares != 0 {
        if err := writeFile(m.path("cpu"), "cpu.shares", 
                           strconv.FormatUint(container.Cgroups.Resources.CpuShares, 10)); err != nil {
            return err
        }
    }
    
    // 设置内存资源限制
    if container.Cgroups.Resources.Memory != 0 {
        if err := writeFile(m.path("memory"), "memory.limit_in_bytes", 
                           strconv.FormatInt(container.Cgroups.Resources.Memory, 10)); err != nil {
            return err
        }
    }
    
    return nil
}
```

### 6.4 进程创建和执行流程

#### 6.4.1 完整的进程创建流程

```go
// runc/libcontainer/container_linux.go
func (c *linuxContainer) Start(process *Process) error {
    c.m.Lock()
    defer c.m.Unlock()
    
    // 1. 检查容器状态
    if c.config.Cgroups.Resources != nil && c.config.Cgroups.Resources.SkipDevices {
        return errors.New("cannot start container with SkipDevices set")
    }
    
    // 2. 创建 exec.Cmd
    cmd := exec.Command("/proc/self/exe", "init")
    cmd.SysProcAttr = &syscall.SysProcAttr{
        Cloneflags: uintptr(c.config.Namespaces.CloneFlags()),
    }
    
    // 3. 设置环境变量
    cmd.Env = append(os.Environ(), 
        "_LIBCONTAINER_INITTYPE=standard",
        "_LIBCONTAINER_INITPIPE="+strconv.Itoa(childPipe),
    )
    
    // 4. 启动进程
    if err := cmd.Start(); err != nil {
        return newSystemErrorWithCause(err, "starting container process")
    }
    
    // 5. 应用 cgroups 设置
    if err := c.cgroupManager.Apply(cmd.Process.Pid); err != nil {
        return err
    }
    
    // 6. 设置资源限制
    if err := c.cgroupManager.Set(c.config); err != nil {
        return err
    }
    
    return nil
}
```

#### 6.4.2 命名空间和 Cgroups 的协同工作

```text
进程创建流程:
1. fork() - 创建子进程
2. clone() - 创建命名空间 (CLONE_NEW*)
3. setns() - 加入现有命名空间 (可选)
4. unshare() - 脱离当前命名空间 (可选)
5. 写入 /sys/fs/cgroup/*/docker/<id>/cgroup.procs - 加入 cgroup
6. 设置 cgroup 资源限制文件
7. execve() - 执行容器进程
```

### 6.5 监控和调试

#### 6.5.1 查看容器的命名空间

```bash
# 查看容器进程的命名空间
sudo ls -la /proc/<container_pid>/ns/

# 输出示例:
lrwxrwxrwx 1 root root 0 Jan 1 12:00 ipc -> ipc:[4026532454]
lrwxrwxrwx 1 root root 0 Jan 1 12:00 mnt -> mnt:[4026532452]
lrwxrwxrwx 1 root root 0 Jan 1 12:00 net -> net:[4026532457]
lrwxrwxrwx 1 root root 0 Jan 1 12:00 pid -> pid:[4026532455]
lrwxrwxrwx 1 root root 0 Jan 1 12:00 user -> user:[4026531837]
lrwxrwxrwx 1 root root 0 Jan 1 12:00 uts -> uts:[4026532453]
```

#### 6.5.2 查看容器的 Cgroups 设置

```bash
# 查看容器的 cgroup 路径
cat /proc/<container_pid>/cgroup

# 查看 CPU 限制
cat /sys/fs/cgroup/cpu/docker/<container_id>/cpu.shares
cat /sys/fs/cgroup/cpu/docker/<container_id>/cpu.cfs_quota_us

# 查看内存限制
cat /sys/fs/cgroup/memory/docker/<container_id>/memory.limit_in_bytes
cat /sys/fs/cgroup/memory/docker/<container_id>/memory.usage_in_bytes

# 查看 I/O 统计
cat /sys/fs/cgroup/blkio/docker/<container_id>/blkio.throttle.io_service_bytes
```

#### 6.5.3 实时监控资源使用

```bash
# 使用 docker stats 命令
docker stats <container_id>

# 直接读取 cgroup 文件
watch -n 1 'cat /sys/fs/cgroup/memory/docker/<container_id>/memory.usage_in_bytes'
```

## 7. 完整执行流程总结

### 7.1 调用链路图

```text
docker run
    ↓
Docker CLI (cli/command/container/run.go)
    ↓ HTTP API 调用
Docker API Server (api/server/router/container/)
    ↓ 内部调用
Docker Daemon (daemon/create.go, daemon/start.go)
    ↓ gRPC 调用
containerd (vendor/github.com/containerd/containerd/)
    ↓ 进程调用
runc (vendor/github.com/opencontainers/runc/)
    ↓ 系统调用
Linux Kernel (namespaces, cgroups, etc.)
```

### 7.2 关键数据结构转换

1. **CLI 参数** → **ContainerConfig + HostConfig**
2. **ContainerConfig** → **OCI Runtime Specification**
3. **OCI Spec** → **containerd Task**
4. **containerd Task** → **runc Container**
5. **runc Container** → **Linux Process**

### 7.3 核心技术点

1. **命名空间隔离**: PID, Network, Mount, IPC, UTS, User
2. **资源限制**: cgroups v1/v2
3. **文件系统**: OverlayFS, AUFS 等联合文件系统
4. **网络**: bridge, host, none 等网络模式
5. **安全**: seccomp, AppArmor, SELinux

## 8. 源码版本说明

本文分析基于以下版本：

- **Docker Engine/Daemon**: moby/moby 最新版本
- **Docker CLI**: docker/cli 最新版本
- **containerd**: 最新版本
- **runc**: 最新版本
- **OCI Runtime Spec**: 最新版本

## 9. 总结

通过对 Docker 源码的深入分析，我们可以看到 `docker run` 命令的执行涉及多个层次的协作：

1. **Docker CLI** 负责命令解析和用户交互
2. **Docker Daemon API** 提供 RESTful 接口
3. **Docker Daemon** 实现核心容器管理逻辑
4. **containerd** 提供容器运行时管理
5. **runc** 实现 OCI 标准的容器运行时

每一层都有明确的职责分工，通过标准化的接口进行通信，这种分层架构使得 Docker 生态系统具有良好的可扩展性和可维护性。

理解这个执行流程对于 Docker 的使用、调试和扩展都具有重要意义，也为我们深入理解容器技术的底层原理提供了宝贵的参考。
