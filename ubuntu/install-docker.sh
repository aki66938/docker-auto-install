#!/bin/bash

# 更新包索引
sudo apt-get update

# 安装必要的依赖包
sudo apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release

# 添加Docker的官方GPG密钥
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

# 设置稳定版仓库
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# 更新apt包索引
sudo apt-get update

# 安装Docker Engine
sudo apt-get install -y docker-ce docker-ce-cli containerd.io

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
