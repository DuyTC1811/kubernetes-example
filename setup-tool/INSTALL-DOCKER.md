# Cài Docker trên Oracle Linux 9

Hướng dẫn ngắn gọn để cài Docker Engine bằng repo chính thức.

## 1) Gỡ bản Docker cũ (nếu có)

```bash
sudo dnf remove -y docker docker-client docker-client-latest docker-common docker-latest docker-latest-logrotate docker-logrotate docker-engine
```

## 2) Thêm Docker repository

```bash
sudo dnf -y install dnf-plugins-core
sudo dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
```

## 3) Cài Docker Engine

```bash
sudo dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo systemctl enable --now docker
```

## 4) Cho phép chạy Docker không cần root

```bash
sudo usermod -aG docker ${USER}
newgrp docker
```

## 5) Kiểm tra

```bash
docker version
docker ps
```

## Tài liệu chính thức

- https://docs.docker.com/engine/install/centos/
