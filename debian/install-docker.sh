#!/bin/bash

# 检查是否为root用户
if [ "$EUID" -ne 0 ]; then 
    echo "请使用root权限运行此脚本"
    exit 1
fi

# 获取Debian版本信息
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS_VERSION=$VERSION_CODENAME
    echo "检测到Debian版本: $VERSION ($OS_VERSION)"
else
    echo "无法确定Debian版本"
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

# 设置稳定版仓库
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian \
  $OS_VERSION stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

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

# 配置Docker镜像加速（使用腾讯云镜像）
mkdir -p /etc/docker
cat > /etc/docker/daemon.json <<EOF
{
  "registry-mirrors": ["https://mirror.ccs.tencentyun.com"],
  "storage-driver": "overlay2"
}
EOF

# 重启Docker服务以应用镜像加速
systemctl daemon-reload
systemctl restart docker

# 安装Docker Compose
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# 安装命令补全（可选）
if [ -d /etc/bash_completion.d ]; then
    curl -L https://raw.githubusercontent.com/docker/compose/master/contrib/completion/bash/docker-compose -o /etc/bash_completion.d/docker-compose
fi

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
echo "2. 已配置腾讯云镜像加速"
echo "3. 已启用overlay2存储驱动"
echo "4. 如果在虚拟机中运行，建议重启系统"
