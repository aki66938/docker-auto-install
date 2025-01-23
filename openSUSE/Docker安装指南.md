# openSUSE系统 Docker 和 Docker Compose 安装指南

本文档提供了在openSUSE系统上安装Docker和Docker Compose的详细说明。

## 系统要求

- openSUSE Leap 15.2或更高版本
- openSUSE Tumbleweed（滚动发行版）
- 64位系统架构（x86_64、aarch64或armv7l）
- 内核版本4.18或更高
- 至少2GB内存（推荐4GB或更多）
- 至少20GB可用磁盘空间
- 支持的文件系统：ext4、xfs、overlay2

## 特别说明

本安装脚本包含以下特性：
1. 自动检测系统架构和openSUSE版本
2. 配置AppArmor增强安全性
3. 启用overlay2存储驱动
4. 配置命令补全（支持bash和zsh）
5. 配置防火墙规则
6. 启用用户命名空间隔离
7. 配置系统参数优化
8. 自动清理未使用的Docker资源

## 安装步骤

1. 首先，确保系统已更新到最新：
   ```bash
   sudo zypper refresh
   sudo zypper update
   ```

2. 下载安装脚本后，添加执行权限：
   ```bash
   chmod +x install-docker.sh
   ```

3. 使用root权限执行脚本：
   ```bash
   sudo ./install-docker.sh
   ```

4. 安装完成后，**重要**：注销当前用户会话并重新登录，或者重启系统（推荐）。

## 验证安装

重新登录后，运行以下命令验证安装：

```bash
# 检查Docker版本
docker --version

# 检查Docker Compose版本
docker compose version

# 检查Docker Buildx版本
docker buildx version

# 验证Docker权限
docker ps

# 运行测试容器
docker run hello-world

# 检查Docker信息
docker info
```

## Docker守护进程配置

脚本已配置了优化的Docker daemon设置。配置文件位于：
```bash
sudo vim /etc/docker/daemon.json
```

默认配置说明：
```json
{
    "storage-driver": "overlay2",
    "storage-opts": [
        "overlay2.override_kernel_check=true"
    ],
    "log-driver": "json-file",
    "log-opts": {
        "max-size": "100m",
        "max-file": "3"
    },
    "registry-mirrors": ["https://mirror.ccs.tencentyun.com"],
    "features": {
        "buildkit": true
    },
    "experimental": false,
    "metrics-addr": "127.0.0.1:9323",
    "max-concurrent-downloads": 10,
    "max-concurrent-uploads": 5,
    "default-ulimits": {
        "nofile": {
            "Name": "nofile",
            "Hard": 64000,
            "Soft": 64000
        }
    },
    "userns-remap": "default",
    "live-restore": true,
    "log-level": "info",
    "userland-proxy": false,
    "no-new-privileges": true
}
```

## 系统参数配置

脚本已配置了优化的系统参数。配置文件位于：
```bash
/etc/sysctl.d/docker.conf
```

主要参数说明：
```bash
# 网络设置
net.ipv4.ip_forward = 1                    # 启用IP转发
net.bridge.bridge-nf-call-iptables = 1     # 启用桥接防火墙
net.ipv4.conf.all.forwarding = 1           # 启用所有接口的IP转发

# 内核参数
kernel.pid_max = 4194304                   # 最大进程ID
fs.file-max = 1000000                      # 最大文件句柄数
fs.inotify.max_user_watches = 524288       # inotify监视限制

# 网络调优
net.core.somaxconn = 32768                 # 连接队列大小
net.ipv4.tcp_max_syn_backlog = 8192        # TCP SYN队列大小
net.core.netdev_max_backlog = 16384        # 网络设备积压队列大小
```

## 内核模块配置

脚本已配置了必要的内核模块。配置文件位于：
```bash
/etc/modules-load.d/docker.conf
```

加载的模块包括：
- overlay：用于overlay2存储驱动
- br_netfilter：用于桥接网络
- ip_vs*：用于负载均衡
- nf_conntrack：用于连接跟踪

## 安全配置

### 1. AppArmor配置

AppArmor提供了强制访问控制（MAC）系统：

```bash
# 检查AppArmor状态
sudo aa-status

# 查看Docker的AppArmor配置
sudo aa-complain /etc/apparmor.d/docker

# 启用严格模式
sudo aa-enforce /etc/apparmor.d/docker
```

### 2. 用户命名空间隔离

脚本已启用用户命名空间重映射，提供了额外的安全层：

```bash
# 检查用户命名空间配置
grep docker /etc/subuid /etc/subgid

# 验证隔离是否生效
docker info | grep -i userns
```

### 3. 安全扫描

推荐使用以下工具进行安全扫描：

```bash
# 安装Trivy
sudo zypper install trivy

# 扫描镜像
trivy image <image-name>

# 安装Docker Bench Security
git clone https://github.com/docker/docker-bench-security.git
cd docker-bench-security
sudo sh docker-bench-security.sh
```

## 性能优化

### 1. 存储优化

```bash
# 定期清理未使用的镜像和容器
docker system prune -af --volumes

# 监控磁盘使用
docker system df -v
```

### 2. 网络优化

```bash
# 使用host网络模式提高性能
docker run --network host myapp

# 使用macvlan网络
docker network create -d macvlan \
  --subnet=192.168.1.0/24 \
  --gateway=192.168.1.1 \
  -o parent=eth0 macnet
```

### 3. 内存优化

```bash
# 限制容器内存
docker run -m 512m --memory-swap 1g myapp

# 监控容器资源使用
docker stats
```

## 故障排除

### 1. 常见错误

#### 权限问题
```bash
# 检查用户组
groups
# 添加用户到docker组
sudo usermod -aG docker $USER
# 重新加载用户组
newgrp docker
```

#### 网络问题
```bash
# 检查Docker网络
docker network ls
# 重建默认网络
docker network rm bridge
docker network create bridge
```

#### 存储问题
```bash
# 检查存储驱动
docker info | grep "Storage Driver"
# 清理存储空间
docker system prune -af
```

### 2. 日志分析

```bash
# 查看Docker日志
sudo journalctl -u docker.service

# 查看容器日志
docker logs <container-id>

# 启用调试模式
sudo systemctl edit docker.service
# 添加以下内容：
[Service]
Environment="DOCKER_OPTS=--debug"
```

### 3. 性能问题

```bash
# 检查系统负载
top
htop

# 检查Docker统计信息
docker stats

# 检查磁盘I/O
iostat -x 1
```

## 最佳实践

1. 定期更新系统和Docker
   ```bash
   sudo zypper update
   ```

2. 使用多阶段构建减小镜像大小
   ```dockerfile
   FROM golang:1.21 as builder
   WORKDIR /app
   COPY . .
   RUN go build -o main

   FROM alpine:latest
   COPY --from=builder /app/main /main
   CMD ["/main"]
   ```

3. 使用健康检查
   ```dockerfile
   HEALTHCHECK --interval=30s --timeout=3s \
     CMD curl -f http://localhost/ || exit 1
   ```

4. 实施资源限制
   ```bash
   docker run \
     --memory="1g" \
     --memory-swap="2g" \
     --cpus="1.5" \
     --pids-limit=100 \
     myapp
   ```

## 其他资源

- [Docker官方文档](https://docs.docker.com/)
- [openSUSE官方文档](https://doc.opensuse.org/)
- [Docker Hub](https://hub.docker.com/)
- [openSUSE Docker Wiki](https://en.opensuse.org/Docker)
- [Docker安全最佳实践](https://docs.docker.com/develop/security-best-practices/)
