# Anolis系统 Docker 和 Docker Compose 安装指南

本文档提供了在Anolis系统上安装Docker和Docker Compose的详细说明。

## 系统要求

- Anolis OS（最新版本）
- 64位系统架构（支持amd64、arm64）
- 至少4GB内存（推荐8GB）
- 内核版本3.10或更高
- 已启用的功能：
  - `/proc`文件系统
  - `cgroup`层级结构
  - 以下内核模块：
    - `overlay2`
    - `br_netfilter`
    - `ip_vs`
    - `ip_vs_rr`
    - `ip_vs_wrr`
    - `ip_vs_sh`
    - `nf_conntrack`

## 安装步骤

1. 下载安装脚本：
   ```bash
   wget https://raw.githubusercontent.com/your-repo/docker-auto-install/main/anolis/install-docker.sh
   ```

2. 给脚本添加执行权限：
   ```bash
   chmod +x install-docker.sh
   ```

3. 以root权限执行安装脚本：
   ```bash
   sudo ./install-docker.sh
   ```

4. 安装完成后，**必须**注销并重新登录以使组权限生效。

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
    "registry-mirrors": ["https://mirror.ccs.tencentyun.com"],
    "storage-driver": "overlay2",
    "storage-opts": ["overlay2.override_kernel_check=true"],
    "log-driver": "json-file",
    "log-opts": {
        "max-size": "100m",
        "max-file": "3"
    },
    "default-ulimits": {
        "nofile": {
            "Name": "nofile",
            "Hard": 64000,
            "Soft": 64000
        }
    },
    "features": {
        "buildkit": true
    },
    "experimental": true,
    "metrics-addr": "127.0.0.1:9323",
    "max-concurrent-downloads": 10,
    "max-concurrent-uploads": 10
}
```

### 系统参数

系统优化参数位于 `/etc/sysctl.d/docker.conf`：

```bash
# 开启IP转发
net.ipv4.ip_forward = 1
# 关闭IPv6
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
# 调整内核参数
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
# 调整系统限制
fs.file-max = 1000000
fs.inotify.max_user_watches = 1048576
fs.inotify.max_user_instances = 8192
# 调整网络参数
net.ipv4.neigh.default.gc_thresh1 = 80000
net.ipv4.neigh.default.gc_thresh2 = 90000
net.ipv4.neigh.default.gc_thresh3 = 100000
# 调整内存参数
vm.max_map_count = 262144
vm.swappiness = 10
```

### 防火墙配置

安装脚本已配置以下防火墙规则：

- Docker默认网桥：docker0
- Docker守护进程端口：2375/tcp, 2376/tcp
- Swarm模式端口：2377/tcp, 7946/tcp/udp, 4789/udp

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
sudo systemctl stop docker

# 禁用Docker服务
sudo systemctl disable docker

# 卸载Docker包
sudo dnf remove -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# 如果安装了NVIDIA Docker支持
sudo dnf remove -y nvidia-container-toolkit

# 删除Docker数据目录
sudo rm -rf /var/lib/docker
sudo rm -rf /var/lib/containerd

# 删除Docker配置
sudo rm -rf /etc/docker

# 删除系统配置
sudo rm -f /etc/sysctl.d/docker.conf

# 重新加载系统参数
sudo sysctl --system
```

## 故障排除

### 常见问题

1. 权限问题
   - 检查用户是否在docker组中：`groups`
   - 如果不在，添加用户到docker组：`sudo usermod -aG docker $USER`
   - 重新登录以使更改生效

2. 服务启动问题
   - 检查服务状态：`systemctl status docker`
   - 查看系统日志：`journalctl -u docker.service`
   - 检查Docker守护进程日志：`sudo tail -f /var/log/docker/daemon.log`

3. 网络问题
   - 检查防火墙规则：`sudo firewall-cmd --list-all`
   - 检查Docker网络：`docker network ls`
   - 检查网络连接：`docker network inspect bridge`

4. 存储问题
   - 检查磁盘空间：`df -h`
   - 查看Docker磁盘使用：`docker system df`
   - 清理未使用的资源：`docker system prune -a`

### 性能优化

1. 存储驱动优化
   - 使用overlay2存储驱动
   - 定期清理未使用的镜像和容器
   - 使用多阶段构建减少镜像大小

2. 网络优化
   - 使用host网络模式提高性能
   - 适当配置DNS
   - 使用合适的网络驱动

3. 资源限制
   - 设置容器的CPU和内存限制
   - 使用cgroup限制资源使用
   - 监控容器资源使用情况

## 安全建议

1. 保持更新
   - 定期更新系统：`sudo dnf update`
   - 更新Docker：`sudo dnf update docker-ce docker-ce-cli containerd.io`
   - 更新容器镜像：`docker pull`

2. 安全配置
   - 使用非root用户运行容器
   - 限制容器权限
   - 使用安全的基础镜像
   - 定期扫描容器漏洞

3. 网络安全
   - 限制对外暴露的端口
   - 使用用户定义网络隔离容器
   - 配置TLS证书

## 其他资源

- [Docker官方文档](https://docs.docker.com/)
- [Anolis OS官方网站](https://openanolis.cn/)
- [Docker Hub](https://hub.docker.com/)
