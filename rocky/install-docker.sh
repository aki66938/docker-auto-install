#!/bin/bash

# 设置错误时退出
set -e

# 设置日志颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# 日志函数
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查是否为root用户
if [ "$EUID" -ne 0 ]; then 
    log_error "请使用root权限运行此脚本"
    exit 1
fi

# 系统检查
log_info "开始系统检查..."

# 检查CPU架构
ARCH=$(uname -m)
case $ARCH in
    x86_64|amd64)
        log_info "检测到x86_64架构"
        ;;
    aarch64|arm64)
        log_info "检测到ARM64架构"
        ;;
    *)
        log_error "不支持的CPU架构: $ARCH"
        exit 1
        ;;
esac

# 检查内存
TOTAL_MEM=$(free -m | awk '/^Mem:/{print $2}')
if [ $TOTAL_MEM -lt 2048 ]; then
    log_warn "系统内存小于2GB，可能会影响Docker性能"
fi

# 检查磁盘空间
ROOT_FREE=$(df -m / | awk 'NR==2 {print $4}')
if [ $ROOT_FREE -lt 20480 ]; then
    log_warn "根分区可用空间小于20GB，建议扩展磁盘空间"
fi

# 获取Rocky Linux版本
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS_VERSION=$VERSION_ID
    if [[ "$OS_VERSION" != "8"* ]] && [[ "$OS_VERSION" != "9"* ]]; then
        log_error "此脚本仅支持Rocky Linux 8或9"
        exit 1
    fi
else
    log_error "无法确定Rocky Linux版本"
    exit 1
fi

log_info "检测到Rocky Linux版本: $OS_VERSION"

# 检查并配置必要的内核参数
log_info "配置内核参数..."
cat > /etc/sysctl.d/docker.conf <<EOF
# 网络设置
net.ipv4.ip_forward = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.conf.all.forwarding = 1
net.ipv4.conf.all.rp_filter = 1

# 内核参数
kernel.pid_max = 4194304
fs.file-max = 1000000
fs.inotify.max_user_watches = 524288
fs.inotify.max_user_instances = 512

# 网络调优
net.core.somaxconn = 32768
net.ipv4.tcp_max_syn_backlog = 8192
net.core.netdev_max_backlog = 16384
net.ipv4.tcp_slow_start_after_idle = 0
net.ipv4.tcp_tw_reuse = 1
EOF

sysctl -p /etc/sysctl.d/docker.conf

# 配置系统限制
log_info "配置系统限制..."
cat > /etc/security/limits.d/docker.conf <<EOF
*       soft    nofile      1048576
*       hard    nofile      1048576
*       soft    nproc       unlimited
*       hard    nproc       unlimited
*       soft    core        unlimited
*       hard    core        unlimited
*       soft    memlock     unlimited
*       hard    memlock     unlimited
EOF

# 删除旧版本Docker
log_info "删除旧版本Docker..."
dnf remove -y docker \
    docker-client \
    docker-client-latest \
    docker-common \
    docker-latest \
    docker-latest-logrotate \
    docker-logrotate \
    docker-engine \
    podman \
    runc

# 安装必要的依赖包
log_info "安装依赖包..."
dnf install -y dnf-plugins-core

# 配置防火墙
log_info "配置防火墙规则..."
if systemctl is-active --quiet firewalld; then
    firewall-cmd --permanent --zone=trusted --add-interface=docker0
    firewall-cmd --permanent --zone=public --add-masquerade
    firewall-cmd --reload
fi

# 添加Docker仓库
log_info "添加Docker仓库..."
dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
sed -i 's/centos/rhel/g' /etc/yum.repos.d/docker-ce.repo

# 安装Docker
log_info "安装Docker..."
dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# 配置Docker daemon
log_info "配置Docker daemon..."
mkdir -p /etc/docker
cat > /etc/docker/daemon.json <<EOF
{
    "storage-driver": "overlay2",
    "log-driver": "json-file",
    "log-opts": {
        "max-size": "100m",
        "max-file": "3"
    },
    "registry-mirrors": [
        "https://mirror.ccs.tencentyun.com"
    ],
    "features": {
        "buildkit": true
    },
    "experimental": false,
    "metrics-addr": "127.0.0.1:9323",
    "max-concurrent-downloads": 10,
    "max-concurrent-uploads": 5,
    "default-ulimits": {
        "nofile": {
            "Name": "nofile",
            "Hard": 64000,
            "Soft": 64000
        }
    },
    "live-restore": true,
    "log-level": "info",
    "userland-proxy": false,
    "no-new-privileges": true,
    "selinux-enabled": true,
    "default-runtime": "runc"
}
EOF

# 配置Containerd
log_info "配置Containerd..."
mkdir -p /etc/containerd
containerd config default > /etc/containerd/config.toml
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/g' /etc/containerd/config.toml

# 配置SELinux
log_info "配置SELinux..."
setsebool -P container_manage_cgroup 1

# 启动服务
log_info "启动Docker服务..."
systemctl enable --now containerd
systemctl enable --now docker

# 检查NVIDIA GPU
if lspci | grep -i nvidia > /dev/null; then
    log_info "检测到NVIDIA GPU，安装NVIDIA Container Toolkit..."
    distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
    curl -s -L https://nvidia.github.io/libnvidia-container/rhel${OS_VERSION}/libnvidia-container.repo | \
        tee /etc/yum.repos.d/nvidia-container-toolkit.repo
    dnf clean expire-cache
    dnf install -y nvidia-container-toolkit
    nvidia-ctk runtime configure --runtime=docker
    systemctl restart docker
fi

# 安装其他工具
log_info "安装其他工具..."
# 安装ctop用于容器监控
wget -O /usr/local/bin/ctop https://github.com/bcicen/ctop/releases/latest/download/ctop-$(uname -m)-linux
chmod +x /usr/local/bin/ctop

# 验证安装
log_info "验证Docker安装..."
docker --version
docker compose version
docker buildx version

# 运行测试容器
log_info "运行测试容器..."
docker run --rm hello-world

log_info "Docker安装完成！"
echo -e "\n${GREEN}请注意：${NC}"
echo "1. 请使用以下命令将用户添加到docker组（替换USERNAME为实际用户名）："
echo "   sudo usermod -aG docker USERNAME"
echo "2. 已配置腾讯云镜像加速"
echo "3. 已优化系统参数和Docker配置"
echo "4. SELinux已配置为允许容器管理"
echo "5. 如果在虚拟机中运行，建议重启系统"

# 显示系统信息
echo -e "\n${GREEN}系统信息：${NC}"
echo "CPU架构: $ARCH"
echo "内存大小: $TOTAL_MEM MB"
echo "根分区可用空间: $ROOT_FREE MB"
echo "Rocky Linux版本: $OS_VERSION"
