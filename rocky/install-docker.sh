#!/bin/bash

# 检查是否为root用户
if [ "$EUID" -ne 0 ]; then 
    echo "请使用root权限运行此脚本"
    exit 1
fi

# 获取Rocky Linux版本
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS_VERSION=$VERSION_ID
else
    echo "无法确定Rocky Linux版本"
    exit 1
fi

echo "检测到Rocky Linux版本: $OS_VERSION"

# 删除旧版本Docker（如果存在）
dnf remove -y docker \
    docker-client \
    docker-client-latest \
    docker-common \
    docker-latest \
    docker-latest-logrotate \
    docker-logrotate \
    docker-engine

# 安装必要的依赖包
dnf install -y dnf-utils \
    device-mapper-persistent-data \
    lvm2

# 添加Docker仓库
dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo

# 替换仓库中的CentOS为Rocky
sed -i 's/centos/rhel/g' /etc/yum.repos.d/docker-ce.repo

# 安装Docker
dnf install -y docker-ce docker-ce-cli containerd.io

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
  "registry-mirrors": ["https://mirror.ccs.tencentyun.com"]
}
EOF

# 重启Docker服务以应用镜像加速
systemctl daemon-reload
systemctl restart docker

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
echo "2. 已配置腾讯云镜像加速"
echo "3. 如果在虚拟机中运行，建议重启系统"
