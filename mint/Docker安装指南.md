# Linux Mint系统 Docker 安装指南

本文档提供了在Linux Mint系统上安装Docker的脚本和使用说明。

## 系统要求

- Linux Mint 21.x 或更高版本
- 64位系统架构 (x86_64, aarch64, armv7l)
- 内核版本3.10或更高
- 最小2GB内存（推荐4GB以上）
- 支持以下特性：
  - overlay2文件系统
  - cgroup v2
  - 用户命名空间
  - seccomp

## 特别说明

本安装脚本包含以下特性：
1. 自动检测系统架构和版本兼容性
2. 使用官方Ubuntu Docker仓库
3. 配置安全加固选项
4. 启用用户命名空间隔离
5. 自动清理未使用的资源
6. 优化的系统参数和内核模块配置
7. 完整的日志记录和错误处理

## 安装步骤

1. 首先，确保系统已更新到最新：
   ```bash
   sudo apt update
   sudo apt upgrade -y
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
```

## Docker守护进程配置

脚本已配置了优化的Docker daemon设置。配置文件位于 `/etc/docker/daemon.json`：

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

## 系统优化配置

### 内核参数

脚本已配置了优化的系统参数（`/etc/sysctl.d/docker.conf`）：

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

### 内核模块

必要的内核模块（`/etc/modules-load.d/docker.conf`）：

```bash
overlay
br_netfilter
ip_vs
ip_vs_rr
ip_vs_wrr
ip_vs_sh
nf_conntrack
```

## 安全特性

1. **用户命名空间隔离**：
   - 默认启用用户命名空间重映射
   - 增强容器与主机的隔离性

2. **资源限制**：
   - 配置了默认的ulimit值
   - 可通过daemon.json进一步定制

3. **特权限制**：
   - 启用no-new-privileges
   - 限制容器获取新特权的能力

4. **日志管理**：
   - 配置了日志轮转
   - 限制了日志文件大小和数量

5. **自动清理**：
   - 每周自动清理未使用的容器、镜像和卷
   - 防止磁盘空间耗尽

## 常用Docker命令

- 管理Docker服务：
  ```bash
  sudo systemctl start docker    # 启动
  sudo systemctl stop docker     # 停止
  sudo systemctl status docker   # 查看状态
  sudo systemctl enable docker   # 开机自启
  ```

- 容器管理：
  ```bash
  docker ps                      # 列出运行容器
  docker ps -a                   # 列出所有容器
  docker start <container>       # 启动容器
  docker stop <container>        # 停止容器
  docker rm <container>          # 删除容器
  ```

- 镜像管理：
  ```bash
  docker images                  # 列出镜像
  docker pull <image>           # 拉取镜像
  docker rmi <image>            # 删除镜像
  docker build -t <tag> .       # 构建镜像
  ```

- 系统维护：
  ```bash
  docker system df              # 查看空间使用
  docker system prune          # 清理未使用资源
  docker system events         # 查看系统事件
  ```

## 故障排除

1. 权限问题：
   ```bash
   # 检查用户组
   groups
   # 添加用户到docker组
   sudo usermod -aG docker $USER
   ```

2. 服务问题：
   ```bash
   # 查看服务日志
   sudo journalctl -u docker.service
   # 查看Docker守护进程日志
   sudo tail -f /var/log/docker.log
   ```

3. 存储问题：
   ```bash
   # 检查磁盘空间
   df -h
   # 查看Docker使用空间
   docker system df -v
   ```

4. 网络问题：
   ```bash
   # 检查网络接口
   ip addr show docker0
   # 检查iptables规则
   sudo iptables -L
   ```

## 性能监控

1. 使用内置指标：
   ```bash
   # 容器统计
   docker stats
   # 系统信息
   docker info
   ```

2. 使用外部工具：
   ```bash
   # 使用ctop查看容器性能
   docker run --rm -ti \
     --name=ctop \
     --volume /var/run/docker.sock:/var/run/docker.sock:ro \
     quay.io/vektorlab/ctop:latest
   ```

## 卸载说明

如需完全卸载Docker，执行以下步骤：

```bash
# 1. 停止所有容器
docker stop $(docker ps -aq)

# 2. 删除所有容器、网络、镜像和卷
docker system prune -af --volumes

# 3. 停止Docker服务
sudo systemctl stop docker
sudo systemctl disable docker

# 4. 卸载Docker包
sudo apt remove -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# 5. 删除数据和配置
sudo rm -rf /var/lib/docker
sudo rm -rf /var/lib/containerd
sudo rm -rf /etc/docker
sudo rm -f /etc/apt/sources.list.d/docker.list
sudo rm -f /etc/apt/keyrings/docker.asc
sudo rm -f /etc/sysctl.d/docker.conf
sudo rm -f /etc/modules-load.d/docker.conf
sudo rm -f /etc/cron.weekly/docker-cleanup
```

## 其他资源

- [Docker官方文档](https://docs.docker.com/)
- [Docker Hub](https://hub.docker.com/)
- [Linux Mint官方文档](https://linuxmint.com/documentation.php)
- [Docker安全最佳实践](https://docs.docker.com/engine/security/)
