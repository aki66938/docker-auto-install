#!/bin/bash

# 检查是否为root用户
if [ "$EUID" -ne 0 ]; then 
    echo "请使用root权限运行此脚本"
    exit 1
fi

# 更新包索引
apt-get update

# 安装必要的依赖包
apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    software-properties-common

# 添加Docker的官方GPG密钥
curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

# 设置Docker仓库（使用Debian仓库，因为Kali基于Debian）
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian \
  bullseye stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

# 更新apt包索引
apt-get update

# 安装Docker Engine
apt-get install -y docker-ce docker-ce-cli containerd.io

# 启动Docker服务
systemctl start docker
systemctl enable docker

# 获取当前登录的非root用户名
CURRENT_USER=$(who am i | awk '{print $1}')

# 将用户添加到docker组
usermod -aG docker $CURRENT_USER

# 安装Docker Compose
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# 验证安装
echo "验证Docker安装："
docker --version
echo "验证Docker Compose安装："
docker-compose --version

# 运行测试容器
echo "运行测试容器："
docker run hello-world

echo "Docker和Docker Compose安装完成！"
echo "请注意："
echo "1. 请注销并重新登录以使用户组权限生效"
echo "2. 如果在虚拟机中运行，建议重启系统"
