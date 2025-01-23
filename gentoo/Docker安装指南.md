# Gentoo Linux系统 Docker 和 Docker Compose 安装指南

本文档提供了在Gentoo Linux系统上安装Docker和Docker Compose的详细说明。

## 系统要求

- Gentoo Linux（最新版本）
- 64位系统
- 正确配置的内核（包含必要的内核选项）
- Portage包管理系统
- 至少4GB内存（推荐8GB）
- 支持的CPU架构：amd64, arm64, ppc64le

## 内核配置要求

以下内核选项必须启用：

```text
General setup:
    [*] POSIX Message Queues
    [*] Control Group support
        [*] Memory controller
        [*] CPU controller
        [*] Block I/O controller
    [*] Namespaces support
        [*] UTS namespace
        [*] IPC namespace
        [*] PID namespace
        [*] Network namespace

[*] Networking support
    Networking options:
        [*] Network packet filtering framework (Netfilter)
        [*] Network classifiers and priority
        [*] Network overlay driver support
        [*] Virtual ethernet pair device
        [*] IP virtual server support
            [*] round-robin scheduling
        [*] TCP/IP networking
            [*] IP: advanced router
            [*] IP: policy routing
            [*] IP: TCP BBR congestion control

Device Drivers:
    [*] Multiple devices driver support (RAID and LVM)
        [*] Device mapper support
            [*] Thin provisioning target
    [*] Network device support
        [*] Network core driver support
            [*] Virtual ethernet pair device

File systems:
    [*] Overlay filesystem support
    [*] Btrfs filesystem support (optional)
    [*] Ext4 filesystem support
        [*] Ext4 POSIX Access Control Lists
        [*] Ext4 Security Labels
```

## 特别说明

本安装脚本包含以下特性：
1. 使用Portage包管理系统安装Docker
2. 配置必要的USE标志
3. 检查内核配置
4. 配置系统参数和模块
5. 启用overlay2存储驱动
6. NVIDIA Docker支持（如果检测到NVIDIA显卡）
7. 系统性能优化
8. BuildKit和实验性功能支持
9. 指标收集功能
10. 高并发下载和上传支持

## 安装步骤

1. 首先，更新Portage树：
   ```bash
   sudo emerge --sync
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

## USE标志配置

脚本会自动配置以下USE标志：

```bash
# /etc/portage/package.use/docker
app-containers/docker btrfs overlay device-mapper
sys-libs/libseccomp static-libs
app-containers/containerd btrfs
app-containers/docker-cli -cli-plugins
```

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
    "max-size": "100m",
    "max-file": "3"
  },
  "registry-mirrors": ["https://mirror.ccs.tencentyun.com"],
  "features": {
    "buildkit": true
  },
  "experimental": true,
  "metrics-addr": "127.0.0.1:9323",
  "max-concurrent-downloads": 10,
  "max-concurrent-uploads": 10
}
```

## NVIDIA Docker支持

如果系统中安装了NVIDIA显卡，脚本会自动安装NVIDIA Docker支持：

```bash
# 安装NVIDIA Docker工具包
sudo emerge -av app-containers/nvidia-container-toolkit

# 验证NVIDIA Docker安装
docker run --gpus all nvidia/cuda:11.0-base nvidia-smi
```

## 系统优化

脚本已配置了系统优化参数。查看配置：

```bash
# 查看系统优化参数
cat /etc/sysctl.d/99-docker.conf

# 应用优化参数
sudo sysctl --system
```

## 常用Docker命令

- 启动Docker服务：
  ```bash
  sudo rc-service docker start
  ```

- 停止Docker服务：
  ```bash
  sudo rc-service docker stop
  ```

- 查看Docker状态：
  ```bash
  sudo rc-service docker status
  ```

- 设置Docker开机自启：
  ```bash
  sudo rc-update add docker default
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
sudo rc-service docker stop

# 移除开机自启
sudo rc-update del docker default

# 卸载Docker包
sudo emerge -C app-containers/docker \
    app-containers/docker-compose \
    app-containers/docker-buildx \
    app-containers/docker-cli \
    app-containers/containerd

# 如果安装了NVIDIA Docker支持
sudo emerge -C app-containers/nvidia-container-toolkit

# 删除Docker数据目录
sudo rm -rf /var/lib/docker
sudo rm -rf /var/lib/containerd

# 删除Docker配置
sudo rm -rf /etc/docker
```

## 故障排除

1. 内核配置问题：
   ```bash
   # 检查内核配置
   cd /usr/src/linux
   make menuconfig
   
   # 重新编译内核
   make && make modules_install && make install
   ```

2. USE标志问题：
   ```bash
   # 检查USE标志
   emerge -pv app-containers/docker
   
   # 更新USE标志后重新编译
   emerge --newuse app-containers/docker
   ```

3. 权限问题：
   ```bash
   # 确认当前用户在docker组中
   groups
   # 如果没有，手动添加
   sudo usermod -aG docker $USER
   ```

4. 服务启动问题：
   ```bash
   # 检查服务状态
   rc-service docker status
   # 查看日志
   tail -f /var/log/messages
   ```

## 性能优化建议

1. 调整内核参数：
   ```bash
   # 编辑内核参数
   sudo vim /etc/sysctl.d/99-docker.conf
   ```

2. 优化存储驱动：
   ```bash
   # 检查当前存储驱动
   docker info | grep "Storage Driver"
   ```

3. 使用高性能文件系统：
   ```bash
   # 检查文件系统
   df -T /var/lib/docker
   ```

## 安全建议

1. 保持系统和Docker更新：
   ```bash
   sudo emerge --sync
   sudo emerge -avuDN @world
   ```

2. 限制容器资源：
   ```bash
   # 限制内存
   docker run -m 512m myapp

   # 限制CPU
   docker run --cpus=.5 myapp
   ```

3. 加固Docker守护进程：
   ```bash
   # 编辑Docker服务配置
   sudo vim /etc/conf.d/docker
   ```

## 其他资源

- [Docker官方文档](https://docs.docker.com/)
- [Gentoo Wiki - Docker](https://wiki.gentoo.org/wiki/Docker)
- [Docker Hub](https://hub.docker.com/)
- [Gentoo Forums](https://forums.gentoo.org/)
