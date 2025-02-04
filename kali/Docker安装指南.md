# Kali Linux系统 Docker 和 Docker Compose 安装指南

本文档提供了在Kali Linux系统上安装Docker和Docker Compose的详细说明。本指南遵循Docker官方最佳实践和安全建议。

## 系统要求

- Kali Linux（基于Debian）
- 支持的系统架构：
  - x86_64 (amd64)
  - aarch64 (arm64)
  - armv7l (armhf)
- 建议内存：2GB或更多
- 内核版本：3.10或更高
- 必需的内核模块：
  - overlay
  - br_netfilter
  - ip_vs
  - ip_vs_rr
  - ip_vs_wrr
  - ip_vs_sh
  - nf_conntrack

## 安装步骤

1. 下载安装脚本：
   ```bash
   wget https://raw.githubusercontent.com/your-repo/docker-auto-install/main/kali/install-docker.sh
   ```

2. 给脚本添加执行权限：
   ```bash
   chmod +x install-docker.sh
   ```

3. 以root权限执行安装脚本：
   ```bash
   sudo ./install-docker.sh
   ```

4. 安装完成后，**必须**注销并重新登录以使用户组权限生效。如果在虚拟机中运行，建议重启系统。

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
```

## 配置说明

### Docker配置

Docker的主要配置文件位于 `/etc/docker/daemon.json`，包含以下优化设置：

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

### 系统参数

系统优化参数位于 `/etc/sysctl.d/docker.conf`：

```bash
# 网络设置
net.ipv4.ip_forward = 1
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.conf.all.forwarding = 1
net.ipv6.conf.all.forwarding = 1

# 内核参数
kernel.pid_max = 4194304
fs.file-max = 1000000
fs.inotify.max_user_watches = 524288
fs.inotify.max_user_instances = 8192

# 网络调优
net.core.somaxconn = 32768
net.ipv4.tcp_max_syn_backlog = 8192
net.core.netdev_max_backlog = 16384
net.ipv4.tcp_slow_start_after_idle = 0
net.ipv4.tcp_tw_reuse = 1
```

### 自动清理

系统配置了每周自动清理未使用的Docker资源：
- 清理脚本位置：`/etc/periodic/weekly/docker-cleanup`
- 清理内容：未使用的容器、镜像、网络和卷
- 执行时间：每周自动执行

## 常用命令

### 服务管理

- 启动Docker服务：
  ```bash
  sudo systemctl start docker
  ```

- 停止Docker服务：
  ```bash
  sudo systemctl stop docker
  ```

- 重启Docker服务：
  ```bash
  sudo systemctl restart docker
  ```

- 查看Docker状态：
  ```bash
  sudo systemctl status docker
  ```

- 设置开机自启：
  ```bash
  sudo systemctl enable docker
  ```

### 容器管理

- 列出运行中的容器：
  ```bash
  docker ps
  ```

- 列出所有容器：
  ```bash
  docker ps -a
  ```

- 启动容器：
  ```bash
  docker start <container-id>
  ```

- 停止容器：
  ```bash
  docker stop <container-id>
  ```

- 删除容器：
  ```bash
  docker rm <container-id>
  ```

### 镜像管理

- 列出本地镜像：
  ```bash
  docker images
  ```

- 拉取镜像：
  ```bash
  docker pull <image-name>
  ```

- 删除镜像：
  ```bash
  docker rmi <image-id>
  ```

### 系统维护

- 查看系统信息：
  ```bash
  docker info
  ```

- 查看磁盘使用：
  ```bash
  docker system df
  ```

- 清理未使用资源：
  ```bash
  docker system prune -a
  ```

## 卸载说明

如需完全卸载Docker，请按以下步骤操作：

```bash
# 停止所有容器
docker stop $(docker ps -aq)

# 删除所有容器
docker rm $(docker ps -aq)

# 删除所有镜像
docker rmi $(docker images -q)

# 停止Docker服务
systemctl stop docker

# 移除开机自启
systemctl disable docker

# 卸载Docker相关包
apt-get remove -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# 删除Docker数据目录
rm -rf /var/lib/docker
rm -rf /var/lib/containerd

# 删除Docker配置
rm -rf /etc/docker

# 删除系统配置
rm -f /etc/sysctl.d/docker.conf
rm -f /etc/modules-load.d/docker.conf

# 删除日志
rm -rf /var/log/docker

# 删除定时清理脚本
rm -f /etc/periodic/weekly/docker-cleanup

# 重新加载系统参数
sysctl --system
```

## 故障排除

### 常见问题

1. 权限问题
   - 检查用户是否在docker组中：`groups`
   - 如果不在，添加用户到docker组：`sudo usermod -aG docker $USER`
   - 重新登录以使更改生效

2. 服务启动问题
   - 检查服务状态：`systemctl status docker`
   - 查看系统日志：`journalctl -u docker`
   - 检查Docker守护进程日志：`docker info`

3. 网络问题
   - 检查IP转发：`sysctl net.ipv4.ip_forward`
   - 检查网络接口：`ip addr show docker0`
   - 检查iptables规则：`iptables -L`

4. 存储问题
   - 检查磁盘空间：`df -h`
   - 查看Docker磁盘使用：`docker system df`
   - 检查存储驱动：`docker info | grep "Storage Driver"`

### 性能优化

1. 存储优化
   - 使用overlay2存储驱动
   - 定期清理未使用的资源
   - 使用多阶段构建减少镜像大小

2. 内存优化
   - 限制容器内存使用
   - 监控内存使用情况
   - 适当调整swap设置

3. 网络优化
   - 使用适当的网络模式
   - 配置DNS
   - 调整网络参数

## 安全建议

1. 基本安全
   - 保持系统和Docker更新
   - 使用非root用户运行容器
   - 限制容器资源使用

2. 网络安全
   - 限制暴露的端口
   - 使用用户定义网络
   - 配置网络隔离

3. 镜像安全
   - 使用官方镜像
   - 定期更新基础镜像
   - 扫描镜像漏洞

## 其他资源

- [Docker官方文档](https://docs.docker.com/)
- [Kali Linux官方网站](https://www.kali.org/)
- [Docker Hub](https://hub.docker.com/)
- [Docker安全最佳实践](https://docs.docker.com/engine/security/)
