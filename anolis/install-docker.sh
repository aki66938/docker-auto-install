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
