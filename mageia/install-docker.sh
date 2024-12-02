#!/bin/bash

# 检查是否为root用户
if [ "$EUID" -ne 0 ]; then 
    echo "请使用root权限运行此脚本"
    exit 1
fi

# 获取Mageia版本信息
if [ -f /etc/mageia-release ]; then
    MAGEIA_VERSION=$(cat /etc/mageia-release | grep -oE '[0-9]+' | head -1)
    echo "检测到Mageia版本: $MAGEIA_VERSION"
else
    echo "无法确定Mageia版本"
    exit 1
fi

# 更新系统
urpmi.update -a

# 安装必要的依赖包
urpmi --auto \
    curl \
    dnf-utils \
    device-mapper-persistent-data \
    lvm2

# 添加Docker仓库
dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo

# 修改仓库配置以适配Mageia
sed -i 's/$releasever/33/g' /etc/yum.repos.d/docker-ce.repo

# 安装Docker
urpmi --auto docker-ce docker-ce-cli containerd.io

# 启动Docker服务
systemctl start docker
systemctl enable docker

# 获取当前登录的非root用户名
CURRENT_USER=$(who am i | awk '{print $1}')

# 将用户添加到docker组
usermod -aG docker $CURRENT_USER

# 配置存储驱动
mkdir -p /etc/docker
cat > /etc/docker/daemon.json <<EOF
{
  "storage-driver": "overlay2"
}
EOF

# 重启Docker服务以应用配置
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
echo "2. 已启用overlay2存储驱动"
echo "3. 如果在虚拟机中运行，建议重启系统"
