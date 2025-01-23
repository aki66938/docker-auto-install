#!/bin/sh

# 设置错误处理
set -e
trap 'echo "错误发生在第 $LINENO 行: $BASH_COMMAND"' ERR

# 检查是否为root用户
if [ "$(id -u)" -ne 0 ]; then 
    echo "请使用root权限运行此脚本"
    exit 1
fi

# 检查是否为Alpine Linux
if [ ! -f /etc/alpine-release ]; then
    echo "此脚本仅支持Alpine Linux"
    exit 1
fi

# 检查系统架构
ARCH=$(uname -m)
case $ARCH in
    x86_64)
        ARCH="x86_64"
        ;;
    aarch64)
        ARCH="aarch64"
        ;;
    armv7l)
        ARCH="armhf"
        ;;
    s390x)
        ARCH="s390x"
        ;;
    ppc64le)
        ARCH="ppc64le"
        ;;
    *)
        echo "不支持的系统架构: $ARCH"
        exit 1
        ;;
esac

# 获取Alpine版本
ALPINE_VERSION=$(cat /etc/alpine-release | cut -d '.' -f1,2)
echo "检测到Alpine版本: $ALPINE_VERSION"
if [ "$(echo "$ALPINE_VERSION < 3.15" | bc)" -eq 1 ]; then
    echo "警告: 建议使用Alpine 3.15或更高版本"
fi

# 检查内存
TOTAL_MEM=$(free -m | awk '/^Mem:/{print $2}')
if [ "$TOTAL_MEM" -lt 1024 ]; then
    echo "警告: 系统内存小于1GB，可能会影响Docker性能"
fi

# 更新系统包索引
echo "更新系统包索引..."
apk update

# 升级所有已安装的包
echo "升级系统..."
apk upgrade

# 安装必要的依赖包
echo "安装必要的依赖包..."
apk add --no-cache \
    ca-certificates \
    curl \
    wget \
    git \
    device-mapper \
    e2fsprogs \
    e2fsprogs-extra \
    ip6tables \
    iptables \
    openrc \
    shadow \
    xz \
    tzdata \
    htop \
    procps \
    coreutils \
    findutils \
    grep \
    gawk \
    sed \
    util-linux \
    bash \
    sudo

# 移除旧版本和冲突包
echo "移除可能冲突的包..."
apk del docker \
    docker-engine \
    docker-compose \
    podman-docker \
    containerd >/dev/null 2>&1 || true

# 添加社区仓库
echo "添加社区仓库..."
echo "http://dl-cdn.alpinelinux.org/alpine/v${ALPINE_VERSION}/community" >> /etc/apk/repositories

# 安装Docker和相关组件
echo "安装Docker和相关组件..."
apk add --no-cache \
    docker \
    docker-cli \
    docker-engine \
    docker-compose \
    docker-buildx \
    containerd \
    docker-compose-bash-completion \
    docker-bash-completion

# 获取当前登录的非root用户名
SUDO_USER=${SUDO_USER:-$(who am i | awk '{print $1}')}

# 创建docker组并添加用户
echo "配置用户组..."
addgroup -S docker >/dev/null 2>&1 || true
if [ -n "$SUDO_USER" ]; then
    adduser $SUDO_USER docker >/dev/null 2>&1 || true
fi

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
    "experimental": true,
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
    "no-new-privileges": true
}
EOF

# 配置系统参数
echo "配置系统参数..."
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

# 应用sysctl参数
sysctl -p /etc/sysctl.d/docker.conf

# 配置内核模块
echo "配置内核模块..."
cat > /etc/modules-load.d/docker.conf <<EOF
overlay
br_netfilter
ip_vs
ip_vs_rr
ip_vs_wrr
ip_vs_sh
nf_conntrack
EOF

# 加载必要的内核模块
for module in $(cat /etc/modules-load.d/docker.conf); do
    modprobe $module || echo "警告: 无法加载模块 $module"
done

# 配置日志
echo "配置日志..."
mkdir -p /var/log/docker
touch /var/log/docker/docker.log
ln -sf /dev/stdout /var/log/docker/docker.log

# 配置定时任务清理
echo "配置自动清理任务..."
cat > /etc/periodic/weekly/docker-cleanup <<EOF
#!/bin/sh
docker system prune -af --volumes
EOF
chmod +x /etc/periodic/weekly/docker-cleanup

# 启动Docker服务
echo "启动Docker服务..."
rc-update add docker boot
service docker start

# 等待Docker启动
echo "等待Docker服务启动..."
timeout=30
while [ $timeout -gt 0 ]; do
    if docker info >/dev/null 2>&1; then
        break
    fi
    timeout=$((timeout - 1))
    sleep 1
done

if [ $timeout -eq 0 ]; then
    echo "错误: Docker服务启动超时"
    exit 1
fi

# 检查NVIDIA GPU
if [ -x "$(command -v lspci)" ] && lspci | grep -i nvidia > /dev/null; then
    echo "检测到NVIDIA GPU，安装NVIDIA Docker支持..."
    apk add --no-cache nvidia-container-toolkit
    nvidia-ctk runtime configure --runtime=docker
    service docker restart
fi

# 验证安装
echo "验证Docker安装..."
docker --version
docker compose version
docker buildx version

# 运行测试容器
echo "运行测试容器..."
docker run --rm hello-world

echo -e "\nDocker安装完成！"
echo -e "\n系统信息："
echo "Docker版本：$(docker --version)"
echo "Docker Compose版本：$(docker compose version)"
echo "Docker Buildx版本：$(docker buildx version)"
echo "存储驱动：$(docker info | grep "Storage Driver")"
echo "日志驱动：$(docker info | grep "Logging Driver")"
echo "Cgroup驱动：$(docker info | grep "Cgroup Driver")"
echo "内核版本：$(uname -r)"
echo "操作系统：$(cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2)"
echo "系统架构：$ARCH"
echo "总内存：${TOTAL_MEM}MB"

echo -e "\n已加载的内核模块："
lsmod | grep -E "overlay|br_netfilter|ip_vs|nf_conntrack"

echo -e "\n重要提示："
echo "1. 请注销并重新登录以使用用户组权限生效"
echo "2. 已启用overlay2存储驱动"
echo "3. 已配置日志轮转（最大100MB，保留3个文件）"
echo "4. 已启用IP转发和桥接过滤"
echo "5. 已启用BuildKit和实验性功能"
echo "6. 已配置腾讯云镜像加速"
echo "7. 已优化系统参数和文件描述符限制"
echo "8. 已配置每周自动清理未使用的Docker资源"
echo "9. 如果在虚拟机中运行，建议重启系统"

# 清理
trap - ERR
