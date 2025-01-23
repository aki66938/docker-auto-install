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

# 检查是否为Manjaro
if ! grep -q "Manjaro" /etc/os-release; then
    log "此脚本仅支持Manjaro Linux"
    exit 1
fi

# 检查磁盘空间
ROOT_DISK_SPACE=$(df -m / | awk 'NR==2 {print $4}')
if [ ${ROOT_DISK_SPACE} -lt 20480 ]; then
    log "警告: 根分区可用空间小于20GB (${ROOT_DISK_SPACE}MB)"
fi

# 更新系统
log "更新系统包数据库..."
pacman-mirrors --fasttrack
pacman -Syyu --noconfirm

# 安装必要的依赖包
log "安装必要的依赖包..."
pacman -S --needed --noconfirm \
    base-devel \
    device-mapper \
    git \
    wget \
    curl \
    gnupg \
    ca-certificates \
    bridge-utils \
    iptables \
    net-tools \
    iproute2 \
    procps \
    htop \
    apparmor \
    audit \
    vim \
    lsof \
    jq

# 检查并安装pamac（如果需要）
if ! command -v pamac &> /dev/null; then
    log "安装pamac..."
    pacman -S --noconfirm pamac-gtk pamac-cli-git
fi

# 安装Docker
log "安装Docker..."
pamac install --no-confirm docker docker-compose docker-buildx

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
    "registry-mirrors": [
        "https://mirror.gcr.io",
        "https://docker.mirrors.ustc.edu.cn"
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
    "userns-remap": "default",
    "live-restore": true,
    "log-level": "info",
    "userland-proxy": false,
    "no-new-privileges": true,
    "default-runtime": "runc",
    "runtimes": {
        "runc": {
            "path": "runc"
        }
    }
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

# TCP优化
net.ipv4.tcp_rmem = 4096 87380 16777216
net.ipv4.tcp_wmem = 4096 87380 16777216
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.ipv4.tcp_mtu_probing = 1
net.ipv4.tcp_congestion_control = bbr

# 连接跟踪
net.netfilter.nf_conntrack_max = 1048576
net.nf_conntrack_max = 1048576
net.netfilter.nf_conntrack_tcp_timeout_established = 86400
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

# 配置AppArmor
if command -v apparmor_parser >/dev/null 2>&1; then
    log "配置AppArmor..."
    systemctl start apparmor
    systemctl enable apparmor
fi

# 创建docker用户和组
log "创建docker用户和组..."
groupadd -f docker
useradd -r -g docker -s /sbin/nologin docker || true

# 获取当前登录的非root用户名
CURRENT_USER=$(who am i | awk '{print $1}')
if [ ! -z "$CURRENT_USER" ]; then
    log "将用户 ${CURRENT_USER} 添加到docker组..."
    usermod -aG docker $CURRENT_USER
fi

# 配置自动清理
log "配置自动清理..."
cat > /etc/cron.weekly/docker-cleanup <<EOF
#!/bin/sh
docker system prune -af --volumes
EOF
chmod +x /etc/cron.weekly/docker-cleanup

# 配置audit
log "配置audit..."
if command -v auditd >/dev/null 2>&1; then
    systemctl start auditd
    systemctl enable auditd
    # 添加Docker相关审计规则
    cat > /etc/audit/rules.d/docker.rules <<EOF
-w /usr/bin/docker -p rwxa -k docker
-w /var/lib/docker -p rwxa -k docker
-w /etc/docker -p rwxa -k docker
-w /usr/lib/systemd/system/docker.service -p rwxa -k docker
-w /etc/default/docker -p rwxa -k docker
-w /etc/docker/daemon.json -p rwxa -k docker
-w /usr/bin/docker-compose -p rwxa -k docker
-w /usr/bin/docker-runc -p rwxa -k docker
EOF
    auditctl -R /etc/audit/rules.d/docker.rules
fi

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

# 安装命令补全
log "安装命令补全..."
# 为bash安装命令补全
if [ -d /usr/share/bash-completion/completions ]; then
    curl -L https://raw.githubusercontent.com/docker/compose/master/contrib/completion/bash/docker-compose -o /usr/share/bash-completion/completions/docker-compose
fi

# 为zsh安装命令补全（如果安装了zsh）
if [ -d /usr/share/zsh/site-functions ]; then
    curl -L https://raw.githubusercontent.com/docker/compose/master/contrib/completion/zsh/_docker-compose -o /usr/share/zsh/site-functions/_docker-compose
fi

# 配置防火墙（如果安装了ufw）
if command -v ufw >/dev/null 2>&1; then
    log "配置UFW防火墙规则..."
    ufw allow 2375/tcp comment 'Docker daemon'
    ufw allow 2376/tcp comment 'Docker daemon TLS'
    ufw allow 7946/tcp comment 'Docker Swarm'
    ufw allow 7946/udp comment 'Docker Swarm'
    ufw allow 4789/udp comment 'Docker Overlay Network'
    ufw reload
fi

# 检查NVIDIA显卡并安装NVIDIA Docker支持
if lspci | grep -i nvidia > /dev/null; then
    log "检测到NVIDIA显卡，安装NVIDIA Docker支持..."
    pamac install --no-confirm nvidia-container-toolkit
    # 配置NVIDIA运行时
    mkdir -p /etc/nvidia-container-runtime
    cat > /etc/nvidia-container-runtime/config.toml <<EOF
disable-require = false
#swarm-resource = "DOCKER_RESOURCE_GPU"
#accept-nvidia-visible-devices-envvar-when-unprivileged = true
#accept-nvidia-visible-devices-as-volume-mounts = false

[nvidia-container-cli]
#root = "/run/nvidia/driver"
#path = "/usr/bin/nvidia-container-cli"
environment = []
#debug = "/var/log/nvidia-container-toolkit.log"
#ldcache = "/etc/ld.so.cache"
load-kmods = true
no-cgroups = false
#user = "root:video"
ldconfig = "@/sbin/ldconfig"

[nvidia-container-runtime]
#debug = "/var/log/nvidia-container-runtime.log"
EOF
    systemctl restart docker
fi

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
log "4. 已配置AppArmor和Audit"
log "5. 已配置防火墙规则"
log "6. 已配置自动清理未使用的Docker资源"
if lspci | grep -i nvidia > /dev/null; then
    log "7. 已配置NVIDIA容器支持"
fi

# 显示系统信息
log "系统信息："
log "- Docker版本：$(docker --version)"
log "- Docker Compose版本：$(docker compose version)"
log "- Docker Buildx版本：$(docker buildx version)"
log "- 存储驱动：$(docker info | grep "Storage Driver")"
log "- Cgroup驱动：$(docker info | grep "Cgroup Driver")"
log "- 内核版本：$(uname -r)"
log "- 安全选项：$(docker info | grep "Security Options")"
