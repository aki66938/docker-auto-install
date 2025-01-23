#!/bin/bash

# 检查是否为root用户
if [ "$EUID" -ne 0 ]; then 
    echo "请使用root权限运行此脚本"
    exit 1
fi

# 检查是否为Arch Linux
if [ ! -f /etc/arch-release ]; then
    echo "此脚本仅支持Arch Linux"
    exit 1
fi

# 更新系统
echo "更新系统包数据库..."
pacman -Syu --noconfirm

# 安装必要的依赖包
echo "安装必要的依赖包..."
pacman -S --needed --noconfirm \
    base-devel \
    device-mapper \
    git \
    curl \
    bridge-utils \
    iproute2 \
    fuse-overlayfs \
    cgroupfs-mount \
    iptables

# 移除旧版本和冲突包
echo "移除可能冲突的包..."
pacman -R --noconfirm docker-compose podman-docker container-tools >/dev/null 2>&1 || true

# 安装Docker
echo "安装Docker和相关组件..."
pacman -S --needed --noconfirm \
    docker \
    docker-buildx \
    docker-compose

# 启动Docker服务
echo "启动Docker服务..."
systemctl start docker
systemctl enable docker

# 获取当前登录的非root用户名
CURRENT_USER=$(who am i | awk '{print $1}')

# 将用户添加到docker组
echo "将用户添加到docker组..."
usermod -aG docker $CURRENT_USER

# 配置Docker
echo "配置Docker..."
mkdir -p /etc/docker
cat > /etc/docker/daemon.json <<EOF
{
  "storage-driver": "overlay2",
  "storage-opts": [
    "overlay2.override_kernel_check=true"
  ],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m",
    "max-file": "3"
  },
  "registry-mirrors": ["https://mirror.ccs.tencentyun.com"],
  "features": {
    "buildkit": true
  },
  "experimental": true
}
EOF

# 配置系统参数
echo "配置系统参数..."
# 允许IP转发
cat > /etc/sysctl.d/docker.conf <<EOF
net.ipv4.ip_forward = 1
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF
sysctl --system

# 配置内核模块
echo "配置内核模块..."
cat > /etc/modules-load.d/docker.conf <<EOF
overlay
br_netfilter
EOF

# 加载必要的内核模块
modprobe overlay
modprobe br_netfilter

# 重启Docker服务以应用配置
echo "重启Docker服务..."
systemctl daemon-reload
systemctl restart docker

# 配置防火墙（如果安装了ufw）
if command -v ufw >/dev/null 2>&1; then
    echo "配置UFW防火墙规则..."
    ufw allow 2375/tcp comment 'Docker Remote API'
    ufw allow 2376/tcp comment 'Docker Secure Remote API'
    ufw allow 7946/tcp comment 'Docker Swarm'
    ufw allow 7946/udp comment 'Docker Swarm'
    ufw allow 4789/udp comment 'Docker Overlay Network'
    ufw reload
fi

# 验证安装
echo "验证Docker安装..."
docker --version
docker compose version

# 运行测试容器
echo "运行测试容器..."
docker run hello-world

echo "Docker和Docker Compose安装完成！"
echo "请注意："
echo "1. 请注销并重新登录以使用用户组权限生效"
echo "2. 已启用overlay2存储驱动"
echo "3. 已配置日志轮转"
echo "4. 已启用IP转发和桥接过滤"
echo "5. 已启用BuildKit和实验性功能"
echo "6. 已配置腾讯云镜像加速"
echo "7. 如果在虚拟机中运行，建议重启系统"

# 显示系统信息
echo -e "\n系统信息："
echo "Docker版本：$(docker --version)"
echo "Docker Compose版本：$(docker compose version)"
echo "存储驱动：$(docker info | grep "Storage Driver")"
echo "Cgroup驱动：$(docker info | grep "Cgroup Driver")"
echo "内核版本：$(uname -r)"
echo "已加载的内核模块："
lsmod | grep -E "overlay|br_netfilter"
