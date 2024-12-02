# Manjaro Linux系统 Docker 和 Docker Compose 安装指南

本文档提供了在Manjaro Linux系统上安装Docker和Docker Compose的详细说明。

## 系统要求

- Manjaro Linux（最新版本）
- 64位系统
- Linux内核版本 5.x 或更高
- 已启用以下内核模块：
  - overlay
  - br_netfilter
  - ip_vs
  - ip_vs_rr
  - ip_vs_wrr
  - ip_vs_sh

## 特别说明

本安装脚本包含以下特性：
1. 使用pamac包管理器安装Docker
2. 自动更新镜像源（使用pacman-mirrors）
3. 配置内核参数和模块
4. 启用overlay2存储驱动
5. 配置命令补全（支持bash和zsh）
6. 配置UFW防火墙规则（如果安装了UFW）
7. NVIDIA Docker支持（如果检测到NVIDIA显卡）
8. 系统性能优化

## 安装步骤

1. 首先，确保系统已更新到最新：
   ```bash
   sudo pacman-mirrors --fasttrack
   sudo pacman -Syyu
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
docker-compose --version

# 验证Docker权限
docker ps

# 运行测试容器
docker run hello-world
```

## 存储驱动配置

脚本已配置使用overlay2存储驱动。配置文件位于：
```bash
sudo vim /etc/docker/daemon.json
```

默认配置如下：
```json
{
  "storage-driver": "overlay2",
  "storage-opts": [
    "overlay2.override_kernel_check=true"
  ],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "registry-mirrors": [
    "https://mirror.gcr.io",
    "https://docker.mirrors.ustc.edu.cn"
  ]
}
```

## NVIDIA Docker支持

如果系统中安装了NVIDIA显卡，脚本会自动安装NVIDIA Docker支持：

```bash
# 验证NVIDIA Docker安装
docker run --gpus all nvidia/cuda:11.0-base nvidia-smi

# 查看NVIDIA Docker配置
nvidia-container-cli info
```

## 内核模块配置

脚本会自动检查和加载必要的内核模块。您可以手动检查：

```bash
# 检查已加载的模块
lsmod | grep -E 'overlay|br_netfilter|ip_vs'

# 手动加载模块
sudo modprobe overlay
sudo modprobe br_netfilter
```

## 系统优化

脚本已经配置了一些系统优化参数。查看优化配置：

```bash
# 查看系统优化参数
cat /etc/sysctl.d/99-docker-tune.conf

# 应用优化参数
sudo sysctl -p /etc/sysctl.d/99-docker-tune.conf
```

## 常用Docker命令

- 启动Docker服务：
  ```bash
  sudo systemctl start docker
  ```

- 停止Docker服务：
  ```bash
  sudo systemctl stop docker
  ```

- 查看Docker状态：
  ```bash
  sudo systemctl status docker
  ```

- 设置Docker开机自启：
  ```bash
  sudo systemctl enable docker
  ```

## 防火墙配置

如果使用UFW防火墙，脚本已配置必要的规则。手动配置方法：

```bash
# 开放Docker端口
sudo ufw allow 2375/tcp
sudo ufw allow 2376/tcp

# 允许容器间通信
sudo ufw allow in on docker0
```

## 镜像加速

脚本已配置国内镜像加速。如需手动修改：

```bash
sudo vim /etc/docker/daemon.json
```

添加或修改以下内容：
```json
{
  "registry-mirrors": [
    "https://mirror.gcr.io",
    "https://docker.mirrors.ustc.edu.cn"
  ]
}
```

## 卸载说明

如需卸载Docker和Docker Compose，执行以下命令：

```bash
# 停止所有运行中的容器
docker stop $(docker ps -aq)

# 删除所有容器
docker rm $(docker ps -aq)

# 删除所有镜像
docker rmi $(docker images -q)

# 停止Docker服务
sudo systemctl stop docker

# 卸载Docker包
sudo pamac remove docker docker-compose

# 如果安装了NVIDIA Docker支持
sudo pamac remove nvidia-container-toolkit

# 删除Docker数据目录
sudo rm -rf /var/lib/docker
sudo rm -rf /var/lib/containerd

# 删除Docker配置
sudo rm -rf /etc/docker
```

## 故障排除

1. 如果遇到权限问题：
   ```bash
   # 确认当前用户在docker组中
   groups
   # 如果没有，手动添加
   sudo usermod -aG docker $USER
   ```

2. 如果Docker守护进程无法启动：
   ```bash
   # 检查系统日志
   sudo journalctl -u docker.service
   ```

3. 如果遇到内核模块问题：
   ```bash
   # 检查内核模块
   lsmod | grep overlay
   # 手动加载模块
   sudo modprobe overlay
   ```

4. 镜像下载慢：
   ```bash
   # 检查当前镜像源
   docker info | grep "Registry Mirrors"
   # 更新镜像源
   sudo vim /etc/docker/daemon.json
   ```

## 性能优化建议

1. 使用更快的存储驱动：
   ```json
   {
     "storage-driver": "overlay2"
   }
   ```

2. 启用TCP BBR拥塞控制：
   ```bash
   # 检查是否启用
   sysctl net.ipv4.tcp_congestion_control
   ```

3. 调整系统限制：
   ```bash
   # 检查当前限制
   ulimit -a
   # 修改限制
   sudo vim /etc/security/limits.conf
   ```

## 安全建议

1. 保持系统和Docker更新：
   ```bash
   sudo pacman-mirrors --fasttrack
   sudo pacman -Syu
   ```

2. 限制容器资源：
   ```bash
   # 限制内存
   docker run -m 512m myapp

   # 限制CPU
   docker run --cpus=.5 myapp
   ```

3. 使用安全扫描：
   ```bash
   # 安装容器安全扫描工具
   sudo pamac install trivy
   ```

## 其他资源

- [Docker官方文档](https://docs.docker.com/)
- [Manjaro Wiki](https://wiki.manjaro.org/)
- [Docker Hub](https://hub.docker.com/)
- [Manjaro论坛](https://forum.manjaro.org/)
