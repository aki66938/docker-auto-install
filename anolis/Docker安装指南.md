# Anolis系统 Docker 和 Docker Compose 安装指南

本文档提供了在Anolis系统上安装Docker和Docker Compose的脚本和使用说明。

## 安装脚本

将以下内容保存为 `install-docker.sh`：

```bash
#!/bin/bash

# 更新包管理器
sudo dnf update -y

# 安装必要的依赖包
sudo dnf install -y yum-utils device-mapper-persistent-data lvm2

# 添加Docker源
sudo dnf config-manager --add-repo=https://download.docker.com/linux/centos/docker-ce.repo

# 安装Docker
sudo dnf install -y docker-ce docker-ce-cli containerd.io

# 启动Docker服务
sudo systemctl start docker
sudo systemctl enable docker

# 将当前用户添加到docker组
sudo usermod -aG docker $USER

# 安装Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# 验证安装
docker --version
docker-compose --version

echo "Docker和Docker Compose安装完成！"
echo "请注销并重新登录以应用组权限更改。"
```

## 使用说明

1. 首先，创建安装脚本：
   ```bash
   vim install-docker.sh
   ```
   将上述脚本内容复制到文件中。

2. 给脚本添加执行权限：
   ```bash
   chmod +x install-docker.sh
   ```

3. 执行安装脚本：
   ```bash
   sudo ./install-docker.sh
   ```

4. 安装完成后，注销并重新登录以使组权限生效。

5. 验证安装：
   ```bash
   # 检查Docker版本
   docker --version
   
   # 检查Docker Compose版本
   docker-compose --version
   
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

## 卸载说明

如需卸载Docker和Docker Compose，可执行以下命令：

```bash
# 停止Docker服务
sudo systemctl stop docker

# 卸载Docker相关包
sudo dnf remove docker-ce docker-ce-cli containerd.io

# 删除Docker数据目录
sudo rm -rf /var/lib/docker

# 删除Docker Compose
sudo rm /usr/local/bin/docker-compose
```

## 注意事项

1. 安装过程需要root权限
2. 确保系统已经更新到最新版本
3. 安装完成后需要重新登录以使用户组权限生效
4. 如果遇到网络问题，可能需要配置代理或更换软件源

## 故障排除

如果遇到问题，可以检查以下几点：

1. 确认系统版本兼容性
2. 检查网络连接
3. 查看Docker服务状态
4. 检查系统日志：`journalctl -u docker.service`
