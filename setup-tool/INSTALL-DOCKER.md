# Install Docker

Follow these steps to install Docker on your system.

## Prerequisites

- A supported Linux distribution (e.g., Ubuntu, Debian, CentOS)
- `sudo` privileges

## 1. Uninstall old versions

```sh
sudo dnf remove docker \
                docker-client \
                docker-client-latest \
                docker-common \
                docker-latest \
                docker-latest-logrotate \
                docker-logrotate \
                docker-engine
```

## 2. Install using the rpm repository

```sh
sudo dnf -y install dnf-plugins-core
sudo dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
```

## 3. Install Docker Engine

```sh
sudo dnf install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo systemctl enable --now docker
```

## 4. Configuring Docker to Use Non-Root User

```sh
sudo usermod -aG docker ${USER}
newgrp docker
```

## 5. Verify Docker Installation

```sh
docker ps
```

---

For more details, visit the [official Docker documentation](https://docs.docker.com/engine/install/centos/).
