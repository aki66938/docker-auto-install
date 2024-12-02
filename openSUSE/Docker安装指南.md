# openSUSE系统 Docker 和 Docker Compose 安装指南

本文档提供了在openSUSE系统上安装Docker和Docker Compose的详细说明。

## 系统要求

- openSUSE Leap 15.2或更高版本
- openSUSE Tumbleweed（滚动发行版）
- 64位系统
- 内核版本4.18或更高
- 至少20GB可用磁盘空间

## 特别说明

本安装脚本包含以下特性：
1. 自动检测openSUSE版本
2. 配置AppArmor（如果可用）
3. 启用overlay2存储驱动
4. 配置命令补全（支持bash和zsh）
5. 配置防火墙规则

## 安装步骤

1. 首先，确保系统已更新到最新：
   ```bash
   sudo zypper refresh
   sudo zypper update
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
  ]
}
```

## AppArmor配置

openSUSE使用AppArmor作为安全模块。脚本已自动配置，但您可以手动管理：

```bash
# 检查AppArmor状态
sudo systemctl status apparmor

# 启动AppArmor
sudo systemctl start apparmor

# 设置开机自启
sudo systemctl enable apparmor

# 查看AppArmor配置文件
ls /etc/apparmor.d/
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

openSUSE默认使用firewalld作为防火墙。脚本已配置以下规则：

```bash
# 查看防火墙规则
sudo firewall-cmd --list-all

# 手动配置（如果需要）
sudo firewall-cmd --permanent --zone=public --add-service=docker
sudo firewall-cmd --permanent --zone=public --add-masquerade
sudo firewall-cmd --reload
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
sudo zypper remove -y docker-ce docker-ce-cli containerd.io

# 删除Docker数据目录
sudo rm -rf /var/lib/docker
sudo rm -rf /var/lib/containerd

# 删除Docker Compose
sudo rm /usr/local/bin/docker-compose

# 删除Docker配置
sudo rm -rf /etc/docker
```

## 故障排除

1. 如果遇到仓库问题：
   ```bash
   # 重新添加Docker仓库
   sudo zypper removerepo docker-ce
   sudo zypper addrepo https://download.docker.com/linux/opensuse/docker-ce.repo
   sudo zypper refresh
   ```

2. 如果出现权限错误：
   ```bash
   # 确认当前用户在docker组中
   groups
   # 如果没有，手动添加
   sudo usermod -aG docker $USER
   ```

3. 如果Docker守护进程无法启动：
   ```bash
   # 检查系统日志
   sudo journalctl -u docker.service
   ```

4. AppArmor相关问题：
   ```bash
   # 检查AppArmor状态
   sudo aa-status
   # 如果需要，重新加载配置
   sudo systemctl reload apparmor
   ```

## 性能优化建议

1. 调整日志配置：
   ```json
   {
     "log-driver": "json-file",
     "log-opts": {
       "max-size": "10m",
       "max-file": "3"
     }
   }
   ```

2. 配置镜像加速：
   ```json
   {
     "registry-mirrors": [
       "https://mirror.gcr.io",
       "https://docker.mirrors.ustc.edu.cn"
     ]
   }
   ```

3. 配置容器DNS：
   ```json
   {
     "dns": ["8.8.8.8", "8.8.4.4"]
   }
   ```

## 安全建议

1. 保持系统和Docker更新：
   ```bash
   sudo zypper update
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
   # 安装漏洞扫描工具
   sudo zypper install openscap-utils
   ```

## 其他资源

- [Docker官方文档](https://docs.docker.com/)
- [openSUSE官方文档](https://doc.opensuse.org/)
- [Docker Hub](https://hub.docker.com/)
- [openSUSE Docker Wiki](https://en.opensuse.org/Docker)
