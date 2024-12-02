# Docker 自动安装脚本

[English](./README_EN.md) | 简体中文

<div align="center">
    <img src="https://www.docker.com/wp-content/uploads/2022/03/horizontal-logo-monochromatic-white.png" alt="Docker Logo" width="400"/>
    <h3>一键安装 Docker 和 Docker Compose</h3>
    <p>适用于所有主流 Linux 发行版的自动化 Docker 安装工具</p>
</div>

## ✨ 特性

- 🚀 零配置，一键安装
- 🔍 自动检测系统类型和架构
- 💻 支持多种 Linux 发行版
- 🔒 从官方源安装，安全可靠
- 🛠️ 自动配置 Docker Compose
- 🎯 智能错误处理机制

## 🎁 支持的系统

- Ubuntu
- Debian
- CentOS
- Rocky Linux
- Fedora
- openSUSE
- Arch Linux
- Manjaro
- Kali Linux
- Raspberry Pi OS
- 以及更多...

## 📦 快速开始

只需要运行以下命令：

```bash
curl -fsSL https://raw.githubusercontent.com/aki66938/docker-auto-install/main/install.sh | sudo bash
```

或者使用 wget：

```bash
wget -qO- https://raw.githubusercontent.com/aki66938/docker-auto-install/main/install.sh | sudo bash
```

## 🔧 安装过程

1. 脚本会自动检测您的系统类型和架构
2. 下载适配您系统的安装脚本
3. 安装必要的依赖包
4. 配置 Docker 官方软件源
5. 安装并配置 Docker Engine
6. 安装 Docker Compose
7. 设置用户权限
8. 启动 Docker 服务
9. 验证安装结果

## ✅ 验证安装

安装完成后，您可以运行以下命令验证安装：

```bash
# 检查 Docker 版本
docker --version

# 检查 Docker Compose 版本
docker-compose --version

# 运行测试容器
docker run hello-world
```

## 📝 注意事项

- 需要 root 权限或 sudo 权限
- 确保系统已连接到互联网
- 建议在安装前备份重要数据
- 如果已安装旧版本 Docker，脚本会自动处理

## 🤝 贡献指南

欢迎提交 Issue 和 Pull Request！

1. Fork 本仓库
2. 创建您的特性分支 (git checkout -b feature/AmazingFeature)
3. 提交您的更改 (git commit -m 'Add some AmazingFeature')
4. 推送到分支 (git push origin feature/AmazingFeature)
5. 打开一个 Pull Request

## 📜 开源协议

本项目采用 MIT 协议 - 详见 [LICENSE](LICENSE) 文件
