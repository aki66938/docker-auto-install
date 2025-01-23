#!/bin/bash

# 检查是否为root用户
if [ "$EUID" -ne 0 ]; then 
    echo "请使用root权限运行此脚本"
    exit 1
fi

# 检查是否为树莓派
if ! grep -q "Raspberry Pi" /proc/cpuinfo; then
    echo "此脚本仅支持Raspberry Pi"
    exit 1
fi

# 检查操作系统版本
. /etc/os-release
if [[ "$VERSION_CODENAME" != "bookworm" && "$VERSION_CODENAME" != "bullseye" ]]; then
    echo "此脚本仅支持Raspberry Pi OS Bookworm(12)或Bullseye(11)"
    exit 1
fi

# 检查内存大小并设置交换空间
TOTAL_MEM=$(free -m | awk '/^Mem:/{print $2}')
echo "检测到系统内存: ${TOTAL_MEM}MB"

# 如果内存小于2GB，增加交换空间
if [ $TOTAL_MEM -lt 2048 ]; then
    echo "系统内存小于2GB，配置交换空间..."
    
    # 检查现有交换空间
    SWAP_SIZE=$(free -m | awk '/^Swap:/{print $2}')
    
    if [ $SWAP_SIZE -lt 1024 ]; then
        # 创建2GB的交换文件
        if [ ! -f /swapfile ]; then
            fallocate -l 2G /swapfile
            chmod 600 /swapfile
            mkswap /swapfile
            swapon /swapfile
            echo '/swapfile none swap sw 0 0' >> /etc/fstab
        fi
    fi
fi

# 卸载旧版本
echo "卸载旧版本的Docker包..."
for pkg in docker.io docker-doc docker-compose podman-docker containerd runc; do
    apt-get remove -y $pkg
done

# 清理旧的Docker数据目录（可选）
read -p "是否清理旧的Docker数据？这将删除所有现有的容器和镜像 [y/N] " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "清理Docker数据目录..."
    systemctl stop docker || true
    rm -rf /var/lib/docker
    rm -rf /var/lib/containerd
fi

# 更新系统
echo "更新系统包..."
apt-get update
apt-get upgrade -y

# 安装必要的依赖
echo "安装必要的依赖..."
apt-get install -y \
    ca-certificates \
    curl \
    gnupg \
    lsb-release

# 创建keyrings目录
install -m 0755 -d /etc/apt/keyrings

# 添加Docker的官方GPG密钥
curl -fsSL https://download.docker.com/linux/raspbian/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc

# 设置Docker仓库
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/raspbian \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  tee /etc/apt/sources.list.d/docker.list > /dev/null

# 更新包索引
apt-get update

# 安装Docker
echo "安装Docker..."
apt-get install -y \
    docker-ce \
    docker-ce-cli \
    containerd.io \
    docker-buildx-plugin \
    docker-compose-plugin

# 启动Docker服务
systemctl start docker
systemctl enable docker

# 配置防火墙（如果启用了firewalld）
if command -v firewall-cmd >/dev/null 2>&1; then
    echo "配置防火墙规则..."
    # 添加docker服务到firewalld
    firewall-cmd --permanent --zone=trusted --add-interface=docker0
    firewall-cmd --permanent --zone=public --add-port=2375/tcp
    firewall-cmd --permanent --zone=public --add-port=2376/tcp
    firewall-cmd --reload
fi

# 配置Docker守护进程
echo "配置Docker守护进程..."
mkdir -p /etc/docker
cat > /etc/docker/daemon.json <<EOF
{
  "storage-driver": "overlay2",
  "storage-opts": [
    "overlay2.override_kernel_check=true"
  ],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "registry-mirrors": [
    "https://mirror.gcr.io",
    "https://docker.mirrors.ustc.edu.cn"
  ],
  "default-address-pools": [
    {
      "base": "172.17.0.0/16",
      "size": 24
    }
  ],
  "experimental": false,
  "features": {
    "buildkit": true
  }
}
EOF

# 配置系统参数
echo "配置系统参数..."
cat > /etc/sysctl.d/99-docker.conf <<EOF
# 允许IP转发
net.ipv4.ip_forward = 1

# 增加网络队列长度
net.core.netdev_max_backlog = 4096
net.core.somaxconn = 4096

# 优化TCP参数
net.ipv4.tcp_max_syn_backlog = 4096
net.ipv4.tcp_slow_start_after_idle = 0
net.ipv4.tcp_tw_reuse = 1
EOF

sysctl -p /etc/sysctl.d/99-docker.conf

# 配置内存限制
echo "配置内存限制..."
cat > /etc/systemd/system/docker.service.d/override.conf <<EOF
[Service]
ExecStart=
ExecStart=/usr/bin/dockerd --default-ulimit nofile=65536:65536
EOF

# 重启Docker服务以应用配置
systemctl daemon-reload
systemctl restart docker

# 安装常用工具
echo "安装常用工具..."
apt-get install -y \
    htop \
    iotop \
    iftop \
    ncdu \
    tree

# 优化SD卡性能
echo "优化SD卡性能..."
cat >> /etc/sysctl.conf <<EOF
# 减少数据写入
vm.dirty_background_ratio = 5
vm.dirty_ratio = 10
vm.dirty_writeback_centisecs = 1500
EOF

# 配置日志轮转
echo "配置日志轮转..."
cat > /etc/logrotate.d/docker <<EOF
/var/lib/docker/containers/*/*.log {
    rotate 7
    daily
    compress
    size=10M
    missingok
    delaycompress
    copytruncate
}
EOF

# 验证安装
echo "验证Docker安装..."
docker --version
docker compose version

# 运行测试容器
echo "运行测试容器..."
docker run hello-world

echo "Docker安装完成！"
echo "请注意："
echo "1. 请注销并重新登录以使用户组权限生效"
echo "2. 已启用overlay2存储驱动"
echo "3. 已配置日志轮转"
echo "4. 已优化系统参数"
echo "5. 已配置交换空间（如果需要）"
echo "6. 已配置镜像加速器"
echo "7. 建议重启系统以应用所有更改"

# 显示系统信息
echo -e "\n系统信息："
echo "Docker版本：$(docker --version)"
echo "Docker Compose版本：$(docker compose version)"
echo "存储驱动：$(docker info | grep "Storage Driver")"
echo "内存使用：$(free -h)"
echo "交换空间：$(swapon --show)"
echo "温度限制：$(vcgencmd get_throttled)"

# 提供性能建议
echo -e "\n性能建议："
echo "1. 考虑使用SSD替代SD卡以提高性能"
echo "2. 定期清理不使用的镜像和容器"
echo "3. 监控系统温度，避免过热"
