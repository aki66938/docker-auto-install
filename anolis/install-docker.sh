#!/bin/bash

# 检查是否以root权限运行
if [ "$EUID" -ne 0 ]; then
    echo "请以root权限运行此脚本"
    exit 1
fi

# 设置错误处理
set -e
trap 'last_command=$current_command; current_command=$BASH_COMMAND' DEBUG
trap 'echo "\"${last_command}\" 命令失败，退出码 $?"' EXIT

# 检查系统架构
ARCH=$(uname -m)
case $ARCH in
    x86_64|amd64)
        ARCH=amd64
        ;;
    aarch64|arm64)
        ARCH=arm64
        ;;
    *)
        echo "不支持的系统架构: $ARCH"
        exit 1
        ;;
esac

echo "开始安装Docker..."

# 更新包管理器
echo "更新包管理器..."
dnf update -y

# 安装必要的依赖包
echo "安装依赖包..."
dnf install -y yum-utils device-mapper-persistent-data lvm2 \
    curl wget git vim htop ca-certificates \
    iptables-services policycoreutils-python-utils \
    selinux-policy-targeted container-selinux

# 添加Docker源
echo "添加Docker仓库..."
dnf config-manager --add-repo=https://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo

# 安装Docker
echo "安装Docker..."
dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# 创建Docker配置目录
mkdir -p /etc/docker

# 配置Docker daemon
echo "配置Docker daemon..."
cat > /etc/docker/daemon.json <<EOF
{
    "registry-mirrors": ["https://mirror.ccs.tencentyun.com"],
    "storage-driver": "overlay2",
    "storage-opts": ["overlay2.override_kernel_check=true"],
    "log-driver": "json-file",
    "log-opts": {
        "max-size": "100m",
        "max-file": "3"
    },
    "default-ulimits": {
        "nofile": {
            "Name": "nofile",
            "Hard": 64000,
            "Soft": 64000
        }
    },
    "features": {
        "buildkit": true
    },
    "experimental": true,
    "metrics-addr": "127.0.0.1:9323",
    "max-concurrent-downloads": 10,
    "max-concurrent-uploads": 10
}
EOF

# 配置系统参数
echo "配置系统参数..."
cat > /etc/sysctl.d/docker.conf <<EOF
# 开启IP转发
net.ipv4.ip_forward = 1
# 关闭IPv6
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
# 调整内核参数
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
# 调整系统限制
fs.file-max = 1000000
fs.inotify.max_user_watches = 1048576
fs.inotify.max_user_instances = 8192
# 调整网络参数
net.ipv4.neigh.default.gc_thresh1 = 80000
net.ipv4.neigh.default.gc_thresh2 = 90000
net.ipv4.neigh.default.gc_thresh3 = 100000
# 调整内存参数
vm.max_map_count = 262144
vm.swappiness = 10
EOF

# 应用系统参数
sysctl --system

# 配置防火墙
echo "配置防火墙规则..."
firewall-cmd --permanent --zone=trusted --add-interface=docker0
firewall-cmd --permanent --zone=trusted --add-port=2375/tcp
firewall-cmd --permanent --zone=trusted --add-port=2376/tcp
firewall-cmd --permanent --zone=trusted --add-port=2377/tcp
firewall-cmd --permanent --zone=trusted --add-port=7946/tcp
firewall-cmd --permanent --zone=trusted --add-port=7946/udp
firewall-cmd --permanent --zone=trusted --add-port=4789/udp
firewall-cmd --reload

# 启动Docker服务
echo "启动Docker服务..."
systemctl start docker
systemctl enable docker

# 配置用户组
echo "配置用户组..."
groupadd -f docker
usermod -aG docker $SUDO_USER

# 检查NVIDIA GPU
if lspci | grep -i nvidia > /dev/null; then
    echo "检测到NVIDIA GPU，安装NVIDIA Docker支持..."
    distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
    curl -s -L https://nvidia.github.io/libnvidia-container/gpgkey | gpg --dearmor > /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
    curl -s -L https://nvidia.github.io/libnvidia-container/$distribution/libnvidia-container.repo | tee /etc/yum.repos.d/nvidia-container-toolkit.repo
    dnf install -y nvidia-container-toolkit
    nvidia-ctk runtime configure --runtime=docker
    systemctl restart docker
fi

# 验证安装
echo "验证安装..."
docker --version
docker compose version
docker buildx version

echo "Docker安装完成！"
echo "请注销并重新登录以应用组权限更改。"

# 清理
trap - EXIT
