# Rocky Linux系统 Docker 和 Docker Compose 安装指南

本文档提供了在Rocky Linux系统上安装Docker和Docker Compose的详细说明。

## 系统要求

- Rocky Linux 8或更高版本
- 64位系统架构（x86_64、aarch64或armv7l）
- 内核版本4.18或更高
- 至少2GB内存（推荐4GB或更多）
- 至少20GB可用磁盘空间
- 支持的文件系统：ext4、xfs、overlay2
- 已启用以下内核模块：
  - overlay：用于overlay2存储驱动
  - br_netfilter：用于容器网络
  - ip_vs*：用于负载均衡
  - nf_conntrack：用于连接跟踪

## 特别说明

本安装脚本包含以下特性：
1. 自动检测系统架构和硬件要求
2. 配置腾讯云镜像加速
3. 自动清理旧版本Docker
4. 配置开机自启动
5. 自动替换仓库配置以适配Rocky Linux
6. 优化内核参数和系统限制
7. 配置SELinux和防火墙规则
8. 支持NVIDIA Container Runtime
9. 安装容器监控工具（ctop）
10. 启用BuildKit和Compose插件

## 安装步骤

1. 首先，确保系统已更新到最新：
   ```bash
   sudo dnf update -y
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
    "registry-mirrors": [
        "https://mirror.ccs.tencentyun.com"
    ],
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
    "live-restore": true,
    "log-level": "info",
    "userland-proxy": false,
    "no-new-privileges": true,
    "selinux-enabled": true,
    "default-runtime": "runc",
    "runtimes": {
        "runc": {
            "path": "runc"
        }
    }
}
```

## 系统优化配置

### 1. 内核参数

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
net.ipv4.conf.all.rp_filter = 1            # 启用反向路径过滤

# 内核参数
kernel.pid_max = 4194304                   # 最大进程ID
fs.file-max = 1000000                      # 最大文件句柄数
fs.inotify.max_user_watches = 524288       # inotify监视限制
fs.inotify.max_user_instances = 512        # inotify实例限制

# 网络调优
net.core.somaxconn = 32768                 # 连接队列大小
net.ipv4.tcp_max_syn_backlog = 8192        # TCP SYN队列大小
net.core.netdev_max_backlog = 16384        # 网络设备积压队列大小
net.ipv4.tcp_slow_start_after_idle = 0     # 禁用空闲后的慢启动
net.ipv4.tcp_tw_reuse = 1                  # 启用TIME-WAIT重用

# TCP优化
net.ipv4.tcp_rmem = 4096 87380 16777216    # TCP读缓冲区
net.ipv4.tcp_wmem = 4096 87380 16777216    # TCP写缓冲区
net.ipv4.tcp_mtu_probing = 1               # 启用MTU探测
net.ipv4.tcp_congestion_control = bbr      # 使用BBR拥塞控制
```

### 2. 系统限制

系统限制配置文件位于：
```bash
/etc/security/limits.d/docker.conf
```

配置说明：
```bash
*       soft    nofile      1048576        # 文件描述符软限制
*       hard    nofile      1048576        # 文件描述符硬限制
*       soft    nproc       unlimited      # 进程数软限制
*       hard    nproc       unlimited      # 进程数硬限制
*       soft    core        unlimited      # 核心转储软限制
*       hard    core        unlimited      # 核心转储硬限制
*       soft    memlock     unlimited      # 内存锁定软限制
*       hard    memlock     unlimited      # 内存锁定硬限制
```

## 安全配置

### 1. SELinux配置

SELinux提供了强制访问控制（MAC）系统：

```bash
# 检查SELinux状态
getenforce

# 查看SELinux上下文
ls -Z /var/lib/docker

# 配置SELinux策略
sudo setsebool -P container_manage_cgroup 1
sudo setsebool -P container_use_devices 0
```

### 2. 防火墙配置

如果使用firewalld，脚本已配置必要的规则：

```bash
# 查看防火墙规则
sudo firewall-cmd --list-all

# 手动配置（如果需要）
sudo firewall-cmd --permanent --zone=public --add-port=2375/tcp
sudo firewall-cmd --permanent --zone=public --add-port=2376/tcp
sudo firewall-cmd --permanent --zone=public --add-masquerade
sudo firewall-cmd --reload
```

### 3. 容器安全

推荐的安全实践：

```bash
# 扫描镜像漏洞
docker scan <image-name>

# 使用非root用户运行容器
docker run -u 1000:1000 <image-name>

# 限制容器资源
docker run --cpus=".5" --memory="512m" --pids-limit=100 <image-name>

# 使用只读根文件系统
docker run --read-only <image-name>
```

### 4. 审计配置

启用Docker审计日志：

```bash
# 安装auditd
sudo dnf install -y audit

# 配置Docker审计规则
cat > /etc/audit/rules.d/docker.rules <<EOF
-w /usr/bin/docker -k docker
-w /var/lib/docker -k docker
-w /etc/docker -k docker
-w /usr/lib/systemd/system/docker.service -k docker
-w /etc/systemd/system/docker.service -k docker
-w /usr/lib/systemd/system/docker.socket -k docker
-w /etc/default/docker -k docker
EOF

# 重新加载审计规则
sudo auditctl -R /etc/audit/rules.d/docker.rules
```

## NVIDIA Container Runtime

如果系统中安装了NVIDIA显卡，脚本会自动安装和配置NVIDIA容器工具包：

```bash
# 验证NVIDIA Docker安装
docker run --gpus all nvidia/cuda:11.0-base nvidia-smi

# 查看NVIDIA运行时配置
nvidia-container-cli info

# 运行GPU加速容器示例
docker run --gpus all tensorflow/tensorflow:latest-gpu nvidia-smi
```

## 性能优化

### 1. 存储优化

```bash
# 定期清理未使用的资源
docker system prune -af --volumes

# 监控磁盘使用
docker system df -v

# 使用多阶段构建减小镜像大小
FROM golang:1.21 as builder
WORKDIR /app
COPY . .
RUN go build -o main

FROM alpine:latest
COPY --from=builder /app/main /main
CMD ["/main"]
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

# 使用ctop监控容器
ctop
```

## 监控和日志

### 1. 容器监控

```bash
# 使用ctop监控容器
ctop

# 查看容器统计信息
docker stats

# 查看容器进程
docker top <container-id>
```

### 2. 日志管理

```bash
# 查看容器日志
docker logs -f <container-id>

# 查看Docker守护进程日志
sudo journalctl -u docker.service

# 配置日志轮转
cat > /etc/logrotate.d/docker <<EOF
/var/lib/docker/containers/*/*.log {
    rotate 7
    daily
    compress
    size=10M
    missingok
    delaycompress
    copytruncate
}
EOF
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
   sudo dnf update -y
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

5. 使用安全扫描
   ```bash
   # 安装Trivy
   sudo dnf install -y trivy
   
   # 扫描镜像
   trivy image <image-name>
   ```

## 其他资源

- [Docker官方文档](https://docs.docker.com/)
- [Rocky Linux文档](https://docs.rockylinux.org/)
- [Docker Hub](https://hub.docker.com/)
- [Docker安全最佳实践](https://docs.docker.com/develop/security-best-practices/)
- [NVIDIA容器工具包文档](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/overview.html)
- [Docker性能优化指南](https://docs.docker.com/config/containers/resource_constraints/)
