#!/bin/bash

# 设置错误时退出
set -e

# 设置日志颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# 清理函数
cleanup() {
    if [ -d "$TMP_DIR" ]; then
        rm -rf "$TMP_DIR"
    fi
}

# 错误处理
handle_error() {
    log_error "安装过程中发生错误，错误代码: $?"
    cleanup
    exit 1
}

# 设置错误处理
trap 'handle_error' ERR

# 检查是否为root用户
if [ "$EUID" -ne 0 ]; then 
    log_error "请使用root权限运行此脚本"
    log_info "使用方法: sudo bash install.sh"
    exit 1
fi

# 检查网络连接
log_step "检查网络连接..."
if ! ping -c 1 google.com >/dev/null 2>&1 && ! ping -c 1 baidu.com >/dev/null 2>&1; then
    log_error "无法连接到互联网，请检查网络连接"
    exit 1
fi

# GitHub仓库信息
GITHUB_REPO="aki66938/docker-auto-install"
GITHUB_BRANCH="main"
RAW_BASE_URL="https://raw.githubusercontent.com/$GITHUB_REPO/$GITHUB_BRANCH"

# 检测系统架构
log_step "检测系统架构..."
ARCH=$(uname -m)
case $ARCH in
    x86_64)
        ARCH="amd64"
        ;;
    aarch64)
        ARCH="arm64"
        ;;
    armv7l)
        ARCH="arm"
        ;;
    *)
        log_error "不支持的系统架构: $ARCH"
        exit 1
        ;;
esac

# 检查系统资源
log_step "检查系统资源..."
TOTAL_MEM=$(free -m | awk '/^Mem:/{print $2}')
if [ $TOTAL_MEM -lt 2048 ]; then
    log_warn "系统内存小于2GB，可能会影响Docker性能"
fi

ROOT_FREE=$(df -m / | awk 'NR==2 {print $4}')
if [ $ROOT_FREE -lt 20480 ]; then
    log_warn "根分区可用空间小于20GB，建议扩展磁盘空间"
fi

# 检测操作系统类型和版本
log_step "检测操作系统..."
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
    VERSION_ID=$VERSION_ID
else
    log_error "无法检测操作系统类型"
    exit 1
fi

# 确定具体的发行版
case $OS in
    ubuntu)
        DISTRO="ubuntu"
        ;;
    debian)
        DISTRO="debian"
        ;;
    centos)
        DISTRO="centos"
        ;;
    fedora)
        DISTRO="fedora"
        ;;
    opensuse*|sles)
        DISTRO="openSUSE"
        ;;
    arch)
        DISTRO="arch"
        ;;
    manjaro)
        DISTRO="manjaro"
        ;;
    kali)
        DISTRO="kali"
        ;;
    mint)
        DISTRO="mint"
        ;;
    anolis)
        DISTRO="anolis"
        ;;
    rocky)
        DISTRO="rocky"
        ;;
    gentoo)
        DISTRO="gentoo"
        ;;
    mageia)
        DISTRO="mageia"
        ;;
    raspbian)
        DISTRO="rpi"
        ;;
    *)
        log_error "不支持的操作系统: $OS"
        exit 1
        ;;
esac

# 显示系统信息
echo -e "\n${GREEN}检测到的系统信息：${NC}"
echo "操作系统: $OS"
echo "版本: $VERSION_ID"
echo "架构: $ARCH"
echo "内存: $TOTAL_MEM MB"
echo "根分区可用空间: $ROOT_FREE MB"
echo -e "将使用 ${GREEN}$DISTRO${NC} 的安装脚本\n"

# 创建临时目录
TMP_DIR=$(mktemp -d)
cd $TMP_DIR || exit 1

# 下载对应的安装脚本
INSTALL_SCRIPT="$DISTRO/install-docker.sh"
log_step "正在下载安装脚本..."

# 尝试多个下载源
download_script() {
    # 先尝试GitHub
    if curl -fsSL "$RAW_BASE_URL/$INSTALL_SCRIPT" -o install-docker.sh; then
        return 0
    fi
    
    # 如果GitHub失败，尝试其他镜像源（示例）
    local MIRROR_URLS=(
        "https://gitee.com/mirrors/$GITHUB_REPO/raw/$GITHUB_BRANCH"
        "https://gitlab.com/mirrors/$GITHUB_REPO/-/raw/$GITHUB_BRANCH"
    )
    
    for url in "${MIRROR_URLS[@]}"; do
        if curl -fsSL "$url/$INSTALL_SCRIPT" -o install-docker.sh; then
            return 0
        fi
    done
    
    return 1
}

if ! download_script; then
    log_error "下载安装脚本失败！"
    cleanup
    exit 1
fi

# 检查脚本完整性
if [ ! -s install-docker.sh ]; then
    log_error "下载的脚本文件为空或不完整！"
    cleanup
    exit 1
fi

# 添加执行权限
chmod +x install-docker.sh

# 执行安装脚本
log_step "开始安装 Docker..."
./install-docker.sh

# 清理临时文件
cleanup

log_info "安装过程完成！"
echo -e "\n${GREEN}验证安装：${NC}"
echo "1. 检查Docker版本："
echo "   docker --version"
echo "2. 检查Docker Compose版本："
echo "   docker compose version"
echo "3. 检查Docker服务状态："
echo "   systemctl status docker"
echo -e "\n${GREEN}下一步操作：${NC}"
echo "1. 将当前用户添加到docker组（替换USERNAME为实际用户名）："
echo "   sudo usermod -aG docker USERNAME"
echo "2. 重新登录以使组权限生效"
echo "3. 运行测试容器："
echo "   docker run hello-world"
