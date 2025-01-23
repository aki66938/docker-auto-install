#!/bin/bash

# 检查是否为root用户
if [ "$EUID" -ne 0 ]; then 
    echo "请使用root权限运行此脚本"
    exit 1
fi

# 检查是否为Gentoo
if [ ! -f /etc/gentoo-release ]; then
    echo "此脚本仅支持Gentoo Linux"
    exit 1
fi

# 更新Portage树
echo "更新Portage树..."
emerge --sync

# 检查并配置必要的USE标志
echo "配置USE标志..."
mkdir -p /etc/portage/package.use
cat > /etc/portage/package.use/docker <<EOF
app-containers/docker btrfs overlay device-mapper
sys-libs/libseccomp static-libs
app-containers/containerd btrfs
app-containers/docker-cli -cli-plugins
EOF

# 检查并配置必要的内核选项
echo "检查内核配置..."
CONFIG_CHECK=(
    "NAMESPACES"
    "NET_NS"
    "PID_NS"
    "IPC_NS"
    "UTS_NS"
    "CGROUPS"
    "CGROUP_CPUACCT"
    "CGROUP_DEVICE"
    "CGROUP_FREEZER"
    "CGROUP_SCHED"
    "CPUSETS"
    "MEMCG"
    "KEYS"
    "VETH"
    "BRIDGE"
    "BRIDGE_NETFILTER"
    "NF_NAT_IPV4"
    "IP_NF_FILTER"
    "IP_NF_TARGET_MASQUERADE"
    "NETFILTER_XT_MATCH_ADDRTYPE"
    "NETFILTER_XT_MATCH_CONNTRACK"
    "NETFILTER_XT_MATCH_IPVS"
    "IP_VS"
    "IP_VS_RR"
    "OVERLAY_FS"
    "EXT4_FS"
    "EXT4_FS_POSIX_ACL"
    "EXT4_FS_SECURITY"
)

KERNEL_CONFIG="/usr/src/linux/.config"
if [ -f "$KERNEL_CONFIG" ]; then
    echo "检查内核配置选项..."
    for option in "${CONFIG_CHECK[@]}"; do
        if ! grep -q "CONFIG_$option=y" "$KERNEL_CONFIG"; then
            echo "警告: CONFIG_$option 未启用"
            echo "请在内核配置中启用此选项"
        fi
    done
else
    echo "警告: 未找到内核配置文件"
fi

# 安装必要的依赖
echo "安装必要的依赖..."
emerge -av \
    sys-libs/libseccomp \
    app-containers/containerd \
    dev-libs/libltdl \
    sys-process/tini \
    app-containers/docker-proxy \
    app-containers/docker-cli

# 安装Docker
echo "安装Docker..."
emerge -av app-containers/docker

# 安装Docker Compose
echo "安装Docker Compose..."
emerge -av app-containers/docker-compose

# 安装Docker Buildx
echo "安装Docker Buildx..."
emerge -av app-containers/docker-buildx

# 启动Docker服务
echo "启动Docker服务..."
rc-update add docker default
rc-service docker start

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
  "experimental": true,
  "metrics-addr": "127.0.0.1:9323",
  "max-concurrent-downloads": 10,
  "max-concurrent-uploads": 10
}
EOF

# 配置系统参数
echo "配置系统参数..."
cat > /etc/sysctl.d/99-docker.conf <<EOF
# 允许IP转发
net.ipv4.ip_forward = 1
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1

# 最大文件句柄数
fs.file-max = 2097152

# 允许的最大跟踪连接条目
net.netfilter.nf_conntrack_max = 1048576

# 增加网络队列长度
net.core.netdev_max_backlog = 16384
net.core.somaxconn = 32768

# 增加TCP最大缓冲区大小
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216

# 启用TCP BBR拥塞控制算法
net.ipv4.tcp_congestion_control = bbr
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
rc-service docker restart

# 检查NVIDIA显卡并安装NVIDIA Docker支持
if lspci | grep -i nvidia > /dev/null; then
    echo "检测到NVIDIA显卡，安装NVIDIA Docker支持..."
    emerge -av app-containers/nvidia-container-toolkit
    rc-service docker restart
fi

# 验证安装
echo "验证Docker安装..."
docker --version
docker compose version
docker buildx version

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
echo "7. 已启用Docker指标收集"
if lspci | grep -i nvidia > /dev/null; then
    echo "8. 已安装NVIDIA Docker支持"
fi
echo "9. 请确保内核已正确配置所有必要选项"
echo "10. 如果在虚拟机中运行，建议重启系统"

# 显示系统信息
echo -e "\n系统信息："
echo "Docker版本：$(docker --version)"
echo "Docker Compose版本：$(docker compose version)"
echo "Docker Buildx版本：$(docker buildx version)"
echo "存储驱动：$(docker info | grep "Storage Driver")"
echo "Cgroup驱动：$(docker info | grep "Cgroup Driver")"
echo "内核版本：$(uname -r)"
echo "已加载的内核模块："
lsmod | grep -E "overlay|br_netfilter"
