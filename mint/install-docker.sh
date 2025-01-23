#!/bin/bash

# 设置错误处理
set -e
trap 'last_command=$current_command; current_command=$BASH_COMMAND' DEBUG
trap 'echo "\"${last_command}\" command completed with exit code $?."' EXIT

# 日志函数
log() {
    echo "[$(date +'%Y-%m-%dT%H:%M:%S%z')]: $@"
}

# 检查是否为root用户
if [ "$EUID" -ne 0 ]; then 
    log "请使用root权限运行此脚本"
    exit 1
fi

# 检查系统架构
ARCH=$(uname -m)
case ${ARCH} in
    x86_64|aarch64|armv7l)
        log "检测到支持的系统架构: ${ARCH}"
        ;;
    *)
        log "不支持的系统架构: ${ARCH}"
        exit 1
        ;;
esac

# 检查内存
TOTAL_MEM=$(free -m | awk '/^Mem:/{print $2}')
if [ ${TOTAL_MEM} -lt 2048 ]; then
    log "警告: 系统内存小于2GB (${TOTAL_MEM}MB)，可能会影响Docker性能"
fi

# 检查Linux Mint版本
if [ -f /etc/linuxmint/info ]; then
    MINT_VERSION=$(cat /etc/linuxmint/info | grep "RELEASE=" | cut -d'=' -f2)
    UBUNTU_CODENAME=$(. /etc/os-release && echo "$UBUNTU_CODENAME")
    log "检测到Linux Mint版本: $MINT_VERSION (基于Ubuntu $UBUNTU_CODENAME)"
else
    log "无法确定Linux Mint版本"
    exit 1
fi

# 更新系统
log "更新系统..."
apt-get update
apt-get upgrade -y

# 安装依赖包
log "安装依赖包..."
apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    software-properties-common \
    iptables \
    bridge-utils \
    net-tools \
    procps \
    wget \
    git \
    htop \
    vim-minimal

# 添加Docker官方GPG密钥
log "添加Docker GPG密钥..."
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc

# 添加Docker官方仓库
log "添加Docker仓库..."
echo \
"deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
$(. /etc/os-release && echo "$UBUNTU_CODENAME") stable" | \
tee /etc/apt/sources.list.d/docker.list > /dev/null

# 更新软件包索引
log "更新软件包索引..."
apt-get update

# 安装Docker
log "安装Docker Engine和相关组件..."
apt-get install -y \
    docker-ce \
    docker-ce-cli \
    containerd.io \
    docker-buildx-plugin \
    docker-compose-plugin

# 配置Docker daemon
log "配置Docker daemon..."
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
    "userns-remap": "default",
    "live-restore": true,
    "log-level": "info",
    "userland-proxy": false,
    "no-new-privileges": true
}
EOF

# 配置系统参数
log "配置系统参数..."
cat > /etc/sysctl.d/docker.conf <<EOF
# 网络设置
net.ipv4.ip_forward = 1
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.conf.all.forwarding = 1
net.ipv6.conf.all.forwarding = 1

# 内核参数
kernel.pid_max = 4194304
fs.file-max = 1000000
fs.inotify.max_user_watches = 524288
fs.inotify.max_user_instances = 8192

# 网络调优
net.core.somaxconn = 32768
net.ipv4.tcp_max_syn_backlog = 8192
net.core.netdev_max_backlog = 16384
net.ipv4.tcp_slow_start_after_idle = 0
net.ipv4.tcp_tw_reuse = 1
EOF

# 配置内核模块
log "配置内核模块..."
cat > /etc/modules-load.d/docker.conf <<EOF
overlay
br_netfilter
ip_vs
ip_vs_rr
ip_vs_wrr
ip_vs_sh
nf_conntrack
EOF

# 加载内核模块
log "加载内核模块..."
modprobe overlay
modprobe br_netfilter
modprobe ip_vs
modprobe ip_vs_rr
modprobe ip_vs_wrr
modprobe ip_vs_sh
modprobe nf_conntrack

# 应用系统参数
log "应用系统参数..."
sysctl --system

# 创建docker用户和组
log "创建docker用户和组..."
groupadd -f docker
useradd -r -g docker -s /sbin/nologin docker || true

# 获取当前登录的非root用户名
CURRENT_USER=$(who am i | awk '{print $1}')
if [ ! -z "$CURRENT_USER" ]; then
    log "将用户 ${CURRENT_USER} 添加到docker组..."
    usermod -aG docker $CURRENT_USER
    log "提示：需要重新登录才能使用docker组权限"
fi

# 配置自动清理
log "配置自动清理..."
cat > /etc/cron.weekly/docker-cleanup <<EOF
#!/bin/sh
docker system prune -af --volumes
EOF
chmod +x /etc/cron.weekly/docker-cleanup

# 启动Docker服务
log "启动Docker服务..."
systemctl enable docker
systemctl start docker

# 等待Docker服务启动
log "等待Docker服务启动..."
timeout=30
while ! docker info >/dev/null 2>&1; do
    if [ $timeout -le 0 ]; then
        log "错误: Docker服务启动超时"
        exit 1
    fi
    timeout=$((timeout-1))
    sleep 1
done

# 验证安装
log "验证Docker安装..."
docker --version
docker compose version
docker buildx version

# 运行测试容器
log "运行测试容器..."
if docker run --rm hello-world >/dev/null; then
    log "Docker测试成功！"
else
    log "警告: Docker测试失败"
    exit 1
fi

log "Docker安装完成！"
log "请注意："
log "1. 请注销并重新登录以使用户组权限生效"
log "2. 如果在虚拟机中运行，建议重启系统"
log "3. 已启用用户命名空间隔离和其他安全特性"
log "4. 系统已配置自动清理未使用的Docker资源"
