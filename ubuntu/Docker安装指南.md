# Ubuntu系统 Docker 和 Docker Compose 安装指南

本文档提供了在Ubuntu系统上安装Docker和Docker Compose的脚本和使用说明。

## 安装脚本

将以下内容保存为 `install-docker.sh`：

```bash
#!/bin/bash
# 脚本内容已保存在同目录下的install-docker.sh文件中
```

## 使用说明

1. 首先，确保你的Ubuntu系统已经更新到最新：
   ```bash
   sudo apt-get update && sudo apt-get upgrade
   ```

2. 给脚本添加执行权限：
   ```bash
   chmod +x install-docker.sh
   ```

3. 执行安装脚本：
   ```bash
   sudo ./install-docker.sh
   ```

4. 安装完成后，注销并重新登录以使组权限生效。

5. 验证安装：
   ```bash
   # 检查Docker版本
   docker --version
   
   # 检查Docker Compose版本
   docker-compose --version
   
   # 运行测试容器
   docker run hello-world
   ```

## 常用Docker命令

- 启动Docker服务：
  ```bash
  sudo systemctl start docker
  ```

- 停止Docker服务：
  ```bash
  sudo systemctl stop docker
  ```

- 查看Docker状态：
  ```bash
  sudo systemctl status docker
  ```

- 设置Docker开机自启：
  ```bash
  sudo systemctl enable docker
  ```

## 卸载说明

如需卸载Docker和Docker Compose，可执行以下命令：

```bash
# 停止Docker服务
sudo systemctl stop docker

# 卸载Docker相关包
sudo apt-get purge docker-ce docker-ce-cli containerd.io
sudo apt-get autoremove -y

# 删除Docker数据目录
sudo rm -rf /var/lib/docker
sudo rm -rf /var/lib/containerd

# 删除Docker Compose
sudo rm /usr/local/bin/docker-compose
```

## 注意事项

1. 安装过程需要root权限
2. 确保系统已经更新到最新版本
3. 安装完成后需要重新登录以使用户组权限生效
4. 如果遇到网络问题，可能需要配置代理或更换软件源

## 故障排除

如果遇到问题，可以检查以下几点：

1. 确认Ubuntu版本兼容性
2. 检查网络连接
3. 查看Docker服务状态：`sudo systemctl status docker`
4. 检查系统日志：`journalctl -u docker.service`
5. 确保没有端口冲突
6. 检查防火墙设置

## 系统要求

- Ubuntu 64位系统
- 建议Ubuntu版本：18.04 LTS或更高版本
- 至少4GB内存
- 内核版本3.10或更高版本
