#!/bin/bash

# 检查是否为root用户
if [ "$EUID" -ne 0 ]; then 
    echo "请使用root权限运行此脚本"
    exit 1
fi

# 检查是否为Manjaro
if ! grep -q "Manjaro" /etc/os-release; then
    echo "此脚本仅支持Manjaro Linux"
    exit 1
fi

# 更新系统
echo "更新系统包数据库..."
pacman-mirrors --fasttrack
pacman -Syyu --noconfirm

# 安装必要的依赖包
echo "安装必要的依赖包..."
pacman -S --needed --noconfirm \
    base-devel \
    device-mapper \
    git \
    wget \
    curl \
    gnupg \
    ca-certificates \
    bridge-utils

# 检查并安装pamac（如果需要）
if ! command -v pamac &> /dev/null; then
    echo "安装pamac..."
    pacman -S --noconfirm pamac-gtk pamac-cli-git
fi

# 安装Docker
echo "安装Docker..."
pamac install --no-confirm docker docker-compose

# 启动Docker服务
echo "启动Docker服务..."
systemctl start docker
systemctl enable docker

# 获取当前登录的非root用户名
CURRENT_USER=$(who am i | awk '{print $1}')

# 将用户添加到docker组
echo "将用户添加到docker组..."
usermod -aG docker $CURRENT_USER

# 配置存储驱动
echo "配置Docker存储驱动..."
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
  ]
}
EOF

# 配置系统参数
echo "配置系统参数..."
# 允许IP转发
echo "net.ipv4.ip_forward = 1" > /etc/sysctl.d/docker.conf
sysctl -p /etc/sysctl.d/docker.conf

# 重启Docker服务以应用配置
echo "重启Docker服务..."
systemctl daemon-reload
systemctl restart docker

# 安装命令补全
echo "安装命令补全..."
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
    echo "配置UFW防火墙规则..."
    ufw allow 2375/tcp
    ufw allow 2376/tcp
    ufw reload
fi

# 检查NVIDIA显卡并安装NVIDIA Docker支持
if lspci | grep -i nvidia > /dev/null; then
    echo "检测到NVIDIA显卡，安装NVIDIA Docker支持..."
    pamac install --no-confirm nvidia-container-toolkit
    systemctl restart docker
fi

# 验证安装
echo "验证Docker安装..."
docker --version
docker-compose --version

# 运行测试容器
echo "运行测试容器..."
docker run hello-world

echo "Docker和Docker Compose安装完成！"
echo "请注意："
echo "1. 请注销并重新登录以使用户组权限生效"
echo "2. 已启用overlay2存储驱动"
echo "3. 已配置日志轮转"
echo "4. 已启用IP转发"
echo "5. 已配置镜像加速器"
if lspci | grep -i nvidia > /dev/null; then
    echo "6. 已安装NVIDIA Docker支持"
fi
echo "7. 如果在虚拟机中运行，建议重启系统"

# 显示系统信息
echo -e "\n系统信息："
echo "Docker版本：$(docker --version)"
echo "Docker Compose版本：$(docker-compose --version)"
echo "存储驱动：$(docker info | grep "Storage Driver")"
echo "Cgroup驱动：$(docker info | grep "Cgroup Driver")"
echo "内核版本：$(uname -r)"

# 检查是否需要额外的内核模块
echo -e "\n检查内核模块..."
modules="overlay br_netfilter ip_vs ip_vs_rr ip_vs_wrr ip_vs_sh"
for module in $modules; do
    if ! lsmod | grep -q "^$module"; then
        echo "加载内核模块: $module"
        modprobe $module
        echo "$module" >> /etc/modules-load.d/docker.conf
    fi
done

# 优化系统设置
echo "优化系统设置..."
cat > /etc/sysctl.d/99-docker-tune.conf <<EOF
# 最大文件句柄数
fs.file-max = 2097152

# 允许的最大跟踪连接条目
net.netfilter.nf_conntrack_max = 1048576
net.nf_conntrack_max = 1048576

# 增加网络队列长度
net.core.netdev_max_backlog = 16384
net.core.somaxconn = 32768

# 增加TCP最大缓冲区大小
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216

# 启用TCP BBR拥塞控制算法
net.ipv4.tcp_congestion_control = bbr
EOF

sysctl -p /etc/sysctl.d/99-docker-tune.conf
