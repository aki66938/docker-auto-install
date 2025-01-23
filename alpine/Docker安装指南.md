# Alpine Linux系统 Docker 和 Docker Compose 安装指南

本文档提供了在Alpine Linux系统上安装Docker和Docker Compose的脚本和使用说明。

## 安装脚本

将以下内容保存为 `install-docker.sh`：

```bash
#!/bin/sh
# 脚本内容已保存在同目录下的install-docker.sh文件中
```

## 使用说明

1. 首先，确保你的Alpine系统已经更新到最新：
   ```bash
   apk update && apk upgrade
   ```

2. 给脚本添加执行权限：
   ```bash
   chmod +x install-docker.sh
   ```

3. 执行安装脚本：
   ```bash
   ./install-docker.sh
   ```

4. 安装完成后，注销并重新登录以使组权限生效。

5. 验证安装：
   ```bash
   # 检查Docker版本
   docker --version
   
   # 检查Docker Compose版本
   docker compose version
   
   # 运行测试容器
   docker run hello-world
   ```

## 常用Docker命令

- 启动Docker服务：
  ```bash
  service docker start
  ```

- 停止Docker服务：
  ```bash
  service docker stop
  ```

- 查看Docker状态：
  ```bash
  service docker status
  ```

- 设置Docker开机自启：
  ```bash
  rc-update add docker boot
  ```

## 卸载说明

如需卸载Docker和Docker Compose，可执行以下命令：

```bash
# 停止Docker服务
service docker stop

# 移除开机自启
rc-update del docker boot

# 卸载Docker相关包
apk del docker docker-cli docker-engine docker-compose docker-buildx containerd

# 删除Docker数据目录
rm -rf /var/lib/docker
rm -rf /var/lib/containerd

# 删除Docker配置
rm -rf /etc/docker
```

## 注意事项

1. 安装过程需要root权限
2. 确保系统已经更新到最新版本
3. 安装完成后需要重新登录以使用户组权限生效
4. Alpine Linux使用OpenRC而不是systemd进行服务管理
5. 如果遇到网络问题，可能需要配置代理或更换软件源

## 故障排除

如果遇到问题，可以检查以下几点：

1. 确认Alpine版本兼容性
2. 检查网络连接
3. 查看Docker服务状态：`service docker status`
4. 检查系统日志：`cat /var/log/docker.log`
5. 确保没有端口冲突
6. 检查防火墙设置
7. 确保必要的内核模块已加载：`lsmod | grep -E "overlay|br_netfilter"`

## 系统要求

- Alpine Linux 64位系统
- 建议Alpine版本：3.15或更高版本
- 至少1GB内存（由于Alpine的轻量级特性）
- 支持以下CPU架构：
  - x86_64 (amd64)
  - armhf
  - aarch64
  - s390x
  - ppc64le

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
  service docker start
  ```

- 停止Docker服务：
  ```bash
  service docker stop
  ```

- 重启Docker服务：
  ```bash
  service docker restart
  ```

- 查看Docker状态：
  ```bash
  service docker status
  ```

- 设置开机自启：
  ```bash
  rc-update add docker boot
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
service docker stop

# 移除开机自启
rc-update del docker boot

# 卸载Docker相关包
apk del docker docker-cli docker-engine docker-compose docker-buildx \
    containerd docker-compose-bash-completion docker-bash-completion

# 如果安装了NVIDIA Docker支持
apk del nvidia-container-toolkit

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
   - 如果不在，添加用户到docker组：`sudo adduser $USER docker`
   - 重新登录以使更改生效

2. 服务启动问题
   - 检查服务状态：`service docker status`
   - 查看系统日志：`cat /var/log/docker/docker.log`
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
- [Alpine Linux官方网站](https://alpinelinux.org/)
- [Docker Hub](https://hub.docker.com/)
- [Alpine Linux Wiki](https://wiki.alpinelinux.org/)
