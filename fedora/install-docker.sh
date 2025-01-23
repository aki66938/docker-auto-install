#!/bin/bash

# 检查是否为root用户
if [ "$EUID" -ne 0 ]; then 
    echo "请使用root权限运行此脚本"
    exit 1
fi

# 获取Fedora版本信息
if [ -f /etc/fedora-release ]; then
    FEDORA_VERSION=$(rpm -E %fedora)
    echo "检测到Fedora版本: $FEDORA_VERSION"
else
    echo "无法确定Fedora版本"
    exit 1
fi

# 更新系统
dnf -y update

# 删除旧版本Docker（如果存在）
dnf remove -y docker \
    docker-client \
    docker-client-latest \
    docker-common \
    docker-latest \
    docker-latest-logrotate \
    docker-logrotate \
    docker-selinux \
    docker-engine-selinux \
    docker-engine \
    podman-docker

# 安装必要的依赖包
dnf -y install \
    dnf-plugins-core \
    device-mapper-persistent-data \
    lvm2

# 添加Docker仓库
dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo

# 安装Docker和相关组件
dnf -y install \
    docker-ce \
    docker-ce-cli \
    containerd.io \
    docker-buildx-plugin \
    docker-compose-plugin

# 启动Docker服务
systemctl start docker
systemctl enable docker

# 获取当前登录的非root用户名
CURRENT_USER=$(who am i | awk '{print $1}')

# 将用户添加到docker组
usermod -aG docker $CURRENT_USER

# 配置Docker
mkdir -p /etc/docker
cat > /etc/docker/daemon.json <<EOF
{
  "storage-driver": "overlay2",
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m",
    "max-file": "3"
  },
  "registry-mirrors": ["https://mirror.ccs.tencentyun.com"]
}
EOF

# 配置SELinux（如果启用）
if [ "$(getenforce)" != "Disabled" ]; then
    # 设置SELinux规则
    setsebool -P container_manage_cgroup 1
fi

# 重启Docker服务以应用配置
systemctl daemon-reload
systemctl restart docker

# 验证安装
echo "验证Docker安装："
docker --version
echo "验证Docker Compose安装："
docker compose version

# 运行测试容器
echo "运行测试容器："
docker run hello-world

echo "Docker和Docker Compose安装完成！"
echo "请注意："
echo "1. 请注销并重新登录以使用用户组权限生效"
echo "2. 已启用overlay2存储驱动"
echo "3. 已配置SELinux策略"
echo "4. 已配置日志轮转"
echo "5. 已配置腾讯云镜像加速"
echo "6. 如果在虚拟机中运行，建议重启系统"
