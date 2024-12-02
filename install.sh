#!/bin/bash

# 检查是否为root用户
if [ "$EUID" -ne 0 ]; then 
    echo "请使用root权限运行此脚本"
    echo "使用方法: sudo bash install.sh"
    exit 1
fi

# GitHub仓库信息
GITHUB_REPO="aki66938/docker-auto-install"
GITHUB_BRANCH="main"
RAW_BASE_URL="https://raw.githubusercontent.com/$GITHUB_REPO/$GITHUB_BRANCH"

# 检测系统架构
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
esac

# 检测操作系统类型和版本
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
    VERSION_ID=$VERSION_ID
else
    echo "无法检测操作系统类型"
    exit 1
fi

# 确定具体的发行版
case $OS in
    ubuntu|debian|raspbian)
        DISTRO=$OS
        ;;
    centos|rhel|fedora|rocky|almalinux)
        if [ "$OS" = "rhel" ] || [ "$OS" = "centos" ] || [ "$OS" = "rocky" ] || [ "$OS" = "almalinux" ]; then
            DISTRO="centos"
        else
            DISTRO=$OS
        fi
        ;;
    opensuse*|sles)
        DISTRO="openSUSE"
        ;;
    arch|manjaro)
        DISTRO="arch"
        ;;
    kali)
        DISTRO="kali"
        ;;
    *)
        echo "不支持的操作系统: $OS"
        exit 1
        ;;
esac

echo "检测到的系统信息："
echo "操作系统: $OS"
echo "版本: $VERSION_ID"
echo "架构: $ARCH"
echo "将使用 $DISTRO 的安装脚本"

# 创建临时目录
TMP_DIR=$(mktemp -d)
cd $TMP_DIR || exit 1

# 下载对应的安装脚本
INSTALL_SCRIPT="$DISTRO/install-docker.sh"
echo "正在下载安装脚本..."
curl -fsSL "$RAW_BASE_URL/$INSTALL_SCRIPT" -o install-docker.sh

if [ ! -f install-docker.sh ]; then
    echo "下载安装脚本失败！"
    rm -rf $TMP_DIR
    exit 1
fi

# 添加执行权限
chmod +x install-docker.sh

# 执行安装脚本
echo "开始安装 Docker 和 Docker Compose..."
./install-docker.sh

# 清理临时文件
cd - > /dev/null
rm -rf $TMP_DIR

echo "安装过程完成！"
echo "您可以使用以下命令来验证安装："
echo "docker --version"
echo "docker-compose --version"
