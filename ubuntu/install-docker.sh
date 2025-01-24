#!/bin/bash

# 设置错误处理
set -e

# 函数：检查命令是否存在
check_command() {
    if ! command -v "$1" >/dev/null 2>&1; then
        echo "错误: $1 未安装成功"
        return 1
    fi
    return 0
}

# 清理旧的Docker安装（如果存在）
for pkg in docker.io docker-doc docker-compose podman-docker containerd runc; do
    sudo apt-get remove -y $pkg || true
done

# 更新包索引
sudo apt-get update

# 安装必要的依赖包
sudo apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release

# 创建keyrings目录（如果不存在）
sudo install -m 0755 -d /etc/apt/keyrings

# 添加Docker的官方GPG密钥
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# 添加Docker的存储库到Apt源
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# 更新apt包索引（使用重试机制）
max_attempts=3
attempt=1
while [ $attempt -le $max_attempts ]; do
    if sudo apt-get update; then
        break
    fi
    echo "尝试 $attempt 更新包索引失败，等待后重试..."
    sleep 5
    attempt=$((attempt + 1))
done

if [ $attempt -gt $max_attempts ]; then
    echo "错误: 无法更新包索引，请检查网络连接"
    exit 1
fi

# 安装Docker Engine和相关组件
if ! sudo apt-get install -y \
    docker-ce \
    docker-ce-cli \
    containerd.io \
    docker-buildx-plugin \
    docker-compose-plugin; then
    echo "错误: Docker包安装失败"
    exit 1
fi

# 确保Docker服务已启动（对于使用systemd的系统）
if command -v systemctl >/dev/null 2>&1; then
    if ! sudo systemctl start docker; then
        echo "错误: 无法启动Docker服务"
        exit 1
    fi
    sudo systemctl enable docker
else
    # 对于不使用systemd的系统（如WSL1）
    if ! sudo service docker start; then
        echo "错误: 无法启动Docker服务"
        exit 1
    fi
fi

# 将当前用户添加到docker组
sudo groupadd docker || true
sudo usermod -aG docker $USER

# 验证安装
installation_success=true

# 检查必要的命令是否存在
for cmd in docker docker-compose; do
    if ! check_command "$cmd"; then
        installation_success=false
    fi
done

# 尝试运行docker version命令来验证docker daemon是否正常运行
if ! docker version > /dev/null 2>&1; then
    echo "错误: Docker守护进程未正常运行"
    installation_success=false
fi

if [ "$installation_success" = true ]; then
    echo "Docker和Docker Compose安装成功！"
    echo "请运行以下命令以应用组权限更改："
    echo "  newgrp docker"
    echo "或者注销并重新登录"
    echo "然后运行以下命令测试安装："
    echo "  docker run hello-world"
else
    echo "错误: Docker安装或配置未完全成功，请检查上述错误信息"
    exit 1
fi
