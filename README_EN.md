# Docker Auto Install Script

English | [简体中文](./README.md)

<div align="center">
    <img src="https://www.docker.com/wp-content/uploads/2022/03/horizontal-logo-monochromatic-white.png" alt="Docker Logo" width="400"/>
    <h3>One-Click Docker and Docker Compose Installer</h3>
    <p>Automated Docker installation tool for all major Linux distributions</p>
</div>

## ✨ Features

- 🚀 Zero configuration, one-click installation
- 🔍 Automatic system detection
- 💻 Multi-distribution support
- 🔒 Secure installation from official sources
- 🛠️ Automated Docker Compose setup
- 🎯 Intelligent error handling

## 🎁 Supported Systems

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
- And more...

## 📦 Quick Start

Just run this command:

```bash
curl -fsSL https://raw.githubusercontent.com/aki66938/docker-auto-install/main/install.sh | sudo bash
```

Or using wget:

```bash
wget -qO- https://raw.githubusercontent.com/aki66938/docker-auto-install/main/install.sh | sudo bash
```

## 🔧 Installation Process

1. Automatic detection of system type and architecture
2. Download of distribution-specific installation script
3. Installation of required dependencies
4. Configuration of Docker official repository
5. Installation and configuration of Docker Engine
6. Installation of Docker Compose
7. User permissions setup
8. Docker service activation
9. Installation verification

## ✅ Verify Installation

After installation, verify your setup with these commands:

```bash
# Check Docker version
docker --version

# Check Docker Compose version
docker-compose --version

# Run test container
docker run hello-world
```

## 📝 Important Notes

- Requires root privileges or sudo access
- Internet connection required
- Backup important data before installation
- Existing Docker installations will be handled automatically

## 🤝 Contributing

Contributions are welcome! Here's how you can help:

1. Fork the repository
2. Create your feature branch (git checkout -b feature/AmazingFeature)
3. Commit your changes (git commit -m 'Add some AmazingFeature')
4. Push to the branch (git push origin feature/AmazingFeature)
5. Open a Pull Request

## 📜 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details
