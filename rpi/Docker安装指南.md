# Raspberry Pi (树莓派) Docker 和 Docker Compose 安装指南

本文档提供了在Raspberry Pi上安装Docker和Docker Compose的详细说明，特别针对ARM架构和资源受限的环境进行了优化。

## 系统要求

- Raspberry Pi 3或更新版本
- Raspberry Pi OS (原Raspbian) Buster或更新版本
- 至少1GB RAM（建议2GB或更多）
- 16GB或更大的SD卡（建议使用Class 10或更快）
- 稳定的电源供应（建议使用官方电源）

## 特别说明

本安装脚本包含以下特性：
1. 自动内存管理和交换空间配置
2. SD卡性能优化
3. Docker守护进程优化
4. 系统参数调整
5. 温度监控
6. 日志管理
7. 镜像加速器配置

## 安装步骤

1. 首先，确保系统已更新到最新：
   ```bash
   sudo apt-get update
   sudo apt-get upgrade -y
   ```

2. 下载安装脚本后，添加执行权限：
   ```bash
   chmod +x install-docker.sh
   ```

3. 使用root权限执行脚本：
   ```bash
   sudo ./install-docker.sh
   ```

4. 安装完成后，**重要**：重启系统以应用所有更改。

## 性能优化

### 内存管理

脚本会自动检查系统内存并在需要时配置交换空间：

```bash
# 查看内存使用情况
free -h

# 查看交换空间
swapon --show

# 手动调整交换空间大小
sudo dphys-swapfile swapoff
sudo nano /etc/dphys-swapfile
sudo dphys-swapfile setup
sudo dphys-swapfile swapon
```

### SD卡优化

为延长SD卡寿命，脚本配置了以下参数：

```bash
# /etc/sysctl.conf
vm.dirty_background_ratio = 5
vm.dirty_ratio = 10
vm.dirty_writeback_centisecs = 1500
```

### Docker守护进程配置

配置文件位于 `/etc/docker/daemon.json`：

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
  ],
  "default-address-pools": [
    {
      "base": "172.17.0.0/16",
      "size": 24
    }
  ]
}
```

## 温度监控

使用以下命令监控系统温度：

```bash
# 查看CPU温度
vcgencmd measure_temp

# 查看CPU频率
vcgencmd get_config arm_freq

# 查看温度限制状态
vcgencmd get_throttled
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

## 资源管理

### 容器资源限制

为避免资源耗尽，建议限制容器资源：

```bash
# 限制内存使用
docker run -m 256m myapp

# 限制CPU使用
docker run --cpus=.5 myapp

# 限制IO带宽
docker run --device-write-bps /dev/sda:1mb myapp
```

### 监控工具

脚本安装了以下监控工具：

```bash
# 系统资源监控
htop

# IO监控
iotop

# 网络监控
iftop

# 磁盘使用分析
ncdu
```

## 日志管理

配置了自动日志轮转（`/etc/logrotate.d/docker`）：

```text
/var/lib/docker/containers/*/*.log {
    rotate 7
    daily
    compress
    size=10M
    missingok
    delaycompress
    copytruncate
}
```

## 镜像管理

### 清理未使用的资源

定期运行以下命令释放空间：

```bash
# 删除未使用的容器
docker container prune

# 删除未使用的镜像
docker image prune

# 删除所有未使用的资源
docker system prune -a
```

### ARM架构注意事项

确保使用ARM兼容的镜像：

```bash
# 查看支持的架构
docker info | grep "Architecture"

# 使用多架构镜像
docker run --platform linux/arm64 myapp
```

## 故障排除

1. 温度过高：
   ```bash
   # 检查CPU温度
   vcgencmd measure_temp
   
   # 降低CPU频率
   sudo nano /boot/config.txt
   # 添加: arm_freq=1000
   ```

2. 内存不足：
   ```bash
   # 增加交换空间
   sudo dphys-swapfile swapoff
   sudo nano /etc/dphys-swapfile
   # 修改 CONF_SWAPSIZE=2048
   sudo dphys-swapfile setup
   sudo dphys-swapfile swapon
   ```

3. SD卡性能问题：
   ```bash
   # 检查SD卡速度
   sudo dd if=/dev/zero of=~/test.tmp bs=500K count=1024
   sudo dd if=~/test.tmp of=/dev/null bs=500K count=1024
   
   # 检查文件系统
   sudo fsck.ext4 -f /dev/mmcblk0p2
   ```

4. Docker启动失败：
   ```bash
   # 检查日志
   sudo journalctl -u docker
   
   # 重置Docker
   sudo systemctl stop docker
   sudo rm -rf /var/lib/docker
   sudo systemctl start docker
   ```

## 性能优化建议

1. 使用SSD替代SD卡：
   ```bash
   # 将Docker根目录迁移到SSD
   sudo nano /etc/docker/daemon.json
   # 添加: "data-root": "/path/to/ssd/docker"
   ```

2. 优化内存使用：
   ```bash
   # 调整GPU内存分配
   sudo nano /boot/config.txt
   # 添加: gpu_mem=16
   ```

3. 启用硬件加速：
   ```bash
   # 检查可用的硬件加速
   ls /dev/video*
   ls /dev/dri/*
   ```

## 安全建议

1. 保持系统更新：
   ```bash
   sudo apt-get update
   sudo apt-get upgrade
   ```

2. 限制容器权限：
   ```bash
   # 以非特权模式运行容器
   docker run --security-opt=no-new-privileges myapp
   ```

3. 监控系统活动：
   ```bash
   # 安装审计工具
   sudo apt-get install auditd
   ```

## 其他资源

- [Docker官方文档](https://docs.docker.com/)
- [Raspberry Pi官方文档](https://www.raspberrypi.org/documentation/)
- [Docker Hub](https://hub.docker.com/search?q=&type=image&architecture=arm)
- [Raspberry Pi论坛](https://www.raspberrypi.org/forums/)
