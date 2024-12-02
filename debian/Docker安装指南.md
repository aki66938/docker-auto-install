# Debian系统 Docker 和 Docker Compose 安装指南

本文档提供了在Debian系统上安装Docker和Docker Compose的脚本和使用说明。

## 系统要求

- Debian 10 (Buster)或更高版本
- 64位系统
- 内核版本3.10或更高

## 特别说明

本安装脚本包含以下特性：
1. 自动检测Debian版本
2. 配置腾讯云镜像加速
3. 启用overlay2存储驱动
4. 配置命令补全
5. 配置开机自启动

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

## 镜像加速配置

脚本已自动配置腾讯云镜像加速。如需手动修改，编辑文件：
```bash
sudo vim /etc/docker/daemon.json
```

默认配置如下：
```json
{
  "registry-mirrors": ["https://mirror.ccs.tencentyun.com"],
  "storage-driver": "overlay2"
}
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

如果使用UFW防火墙，需要放行Docker端口：

```bash
# 安装UFW（如果未安装）
sudo apt-get install -y ufw

# 开放Docker端口
sudo ufw allow 2375/tcp
sudo ufw allow 2376/tcp

# 重新加载防火墙配置
sudo ufw reload
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
sudo apt-get purge -y docker-ce docker-ce-cli containerd.io
sudo apt-get autoremove -y

# 删除Docker数据目录
sudo rm -rf /var/lib/docker
sudo rm -rf /var/lib/containerd

# 删除Docker Compose
sudo rm /usr/local/bin/docker-compose

# 删除Docker配置和命令补全
sudo rm -rf /etc/docker
sudo rm /etc/apt/sources.list.d/docker.list
sudo rm /etc/bash_completion.d/docker-compose
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

3. 存储问题：
   ```bash
   # 检查磁盘空间
   df -h
   # 清理未使用的Docker资源
   docker system prune
   ```

4. 网络问题：
   ```bash
   # 检查Docker网络
   docker network ls
   # 重启Docker服务
   sudo systemctl restart docker
   ```

## 性能优化建议

1. 调整存储驱动配置：
   ```json
   {
     "storage-driver": "overlay2",
     "storage-opts": [
       "overlay2.override_kernel_check=true"
     ]
   }
   ```

2. 限制容器日志大小：
   ```json
   {
     "log-driver": "json-file",
     "log-opts": {
       "max-size": "10m",
       "max-file": "3"
     }
   }
   ```

3. 配置容器DNS：
   ```json
   {
     "dns": ["8.8.8.8", "8.8.4.4"]
   }
   ```

## 安全建议

1. 定期更新系统和Docker：
   ```bash
   sudo apt update && sudo apt upgrade -y
   ```

2. 限制容器资源使用：
   ```bash
   # 例如，限制内存使用
   docker run -m 512m your-container
   ```

3. 使用用户命名空间：
   ```json
   {
     "userns-remap": "default"
   }
   ```

## 其他资源

- [Docker官方文档](https://docs.docker.com/)
- [Docker Hub](https://hub.docker.com/)
- [Debian官方文档](https://www.debian.org/doc/)
- [Debian Wiki - Docker](https://wiki.debian.org/Docker)
