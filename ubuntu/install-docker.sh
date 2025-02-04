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

# 下载并添加Docker的官方GPG密钥
# 如果下载失败，尝试使用不同的下载方式
if ! curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg; then
    echo "警告: 使用curl下载GPG密钥失败，尝试使用wget..."
    if ! wget -qO- https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg; then
        echo "错误: 无法下载Docker的GPG密钥"
        exit 1
    fi
fi

# 设置正确的权限
sudo chmod a+r /etc/apt/keyrings/docker.gpg

# 添加Docker的存储库到Apt源
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# 更新apt包索引
if ! sudo apt-get update; then
    echo "错误: 无法更新包索引，可能是由于GPG密钥问题"
    echo "请检查 /etc/apt/keyrings/docker.gpg 文件是否存在且权限正确"
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
