#!/bin/bash

# 检查是否为root用户
if [ "$EUID" -ne 0 ]; then 
    echo "请使用root权限运行此脚本"
    exit 1
fi

# 检测openSUSE版本
if [ -f /etc/os-release ]; then
    . /etc/os-release
    SUSE_VERSION=$VERSION_ID
    echo "检测到openSUSE版本: $SUSE_VERSION"
else
    echo "无法确定openSUSE版本"
    exit 1
fi

# 更新系统
zypper refresh
zypper update -y

# 删除旧版本Docker（如果存在）
zypper remove -y docker \
    docker-client \
    docker-client-latest \
    docker-common \
    docker-latest \
    docker-latest-logrotate \
    docker-logrotate \
    docker-engine

# 安装必要的依赖包
zypper install -y \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    device-mapper \
    git \
    wget

# 添加Docker仓库
# 首先删除可能存在的旧仓库
zypper removerepo docker-ce || true
zypper addrepo https://download.docker.com/linux/opensuse/docker-ce.repo

# 刷新仓库
zypper refresh

# 安装Docker
zypper install -y docker-ce docker-ce-cli containerd.io

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
  "storage-driver": "overlay2",
  "storage-opts": [
    "overlay2.override_kernel_check=true"
  ]
}
EOF

# AppArmor配置（如果启用）
if command -v apparmor_parser >/dev/null 2>&1; then
    zypper install -y apparmor-parser
    systemctl start apparmor
    systemctl enable apparmor
fi

# 重启Docker服务以应用配置
systemctl daemon-reload
systemctl restart docker

# 安装Docker Compose
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# 安装命令补全
# 为bash安装命令补全
if [ -d /etc/bash_completion.d ]; then
    curl -L https://raw.githubusercontent.com/docker/compose/master/contrib/completion/bash/docker-compose -o /etc/bash_completion.d/docker-compose
fi

# 为zsh安装命令补全（如果安装了zsh）
if [ -d /usr/share/zsh/site-functions ]; then
    curl -L https://raw.githubusercontent.com/docker/compose/master/contrib/completion/zsh/_docker-compose -o /usr/share/zsh/site-functions/_docker-compose
fi

# 配置防火墙
if command -v firewall-cmd >/dev/null 2>&1; then
    # 添加docker服务到防火墙
    firewall-cmd --permanent --zone=public --add-service=docker
    firewall-cmd --permanent --zone=public --add-masquerade
    firewall-cmd --reload
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
echo "3. 已配置AppArmor（如果可用）"
echo "4. 已配置防火墙规则"
echo "5. 如果在虚拟机中运行，建议重启系统"

# 显示系统信息
echo -e "\n系统信息："
echo "Docker版本：$(docker --version)"
echo "Docker Compose版本：$(docker-compose --version)"
echo "存储驱动：$(docker info | grep "Storage Driver")"
echo "Cgroup驱动：$(docker info | grep "Cgroup Driver")"
