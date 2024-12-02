# Kali Linux系统 Docker 和 Docker Compose 安装指南

本文档提供了在Kali Linux系统上安装Docker和Docker Compose的脚本和使用说明。

## 特别说明

Kali Linux是基于Debian的安全渗透测试发行版，本安装脚本使用Debian的Docker仓库来确保稳定性。

## 系统要求

- Kali Linux 2020.1或更高版本
- 64位系统
- 至少4GB RAM
- 启用了虚拟化支持（如果在虚拟机中运行）

## 安装步骤

1. 首先，确保系统已更新到最新：
   ```bash
   sudo apt update && sudo apt upgrade -y
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

## 安全注意事项

1. 在Kali Linux中使用Docker时，建议：
   - 定期更新Docker和系统
   - 注意容器的权限设置
   - 使用私有镜像仓库
   - 避免在Docker容器中运行未知来源的镜像

2. 在渗透测试环境中使用Docker：
   - 为不同的测试环境创建独立的容器
   - 使用volumes来持久化重要数据
   - 注意网络安全配置

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
sudo apt-get purge -y docker-ce docker-ce-cli containerd.io
sudo apt-get autoremove -y

# 删除Docker数据目录
sudo rm -rf /var/lib/docker
sudo rm -rf /var/lib/containerd

# 删除Docker Compose
sudo rm /usr/local/bin/docker-compose

# 删除Docker配置
sudo rm -rf /etc/docker
sudo rm /etc/apt/sources.list.d/docker.list
```

## 故障排除

1. 如果出现权限错误：
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

3. 网络问题：
   ```bash
   # 检查Docker网络
   docker network ls
   # 重启Docker服务
   sudo systemctl restart docker
   ```

4. 存储问题：
   ```bash
   # 检查磁盘空间
   df -h
   # 清理未使用的Docker资源
   docker system prune
   ```

## 其他资源

- [Docker官方文档](https://docs.docker.com/)
- [Docker Hub](https://hub.docker.com/)
- [Docker安全最佳实践](https://docs.docker.com/engine/security/security/)
