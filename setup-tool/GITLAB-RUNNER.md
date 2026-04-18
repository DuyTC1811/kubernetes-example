# Cài GitLab Runner (Shell Executor)

Tài liệu này hướng dẫn cài GitLab Runner trên Oracle Linux 9 để chạy CI/CD jobs.

## 1) Cài GitLab Runner

```bash
curl -L "https://packages.gitlab.com/install/repositories/runner/gitlab-runner/script.rpm.sh" | sudo bash
sudo dnf -y install gitlab-runner
sudo systemctl enable --now gitlab-runner
```

## 2) Đăng ký runner

### Cách tương tác (interactive)

```bash
sudo gitlab-runner register
```

Bạn cần nhập:

- URL GitLab (ví dụ: `https://gitlab.example.com`)
- Registration token (trong **Project > Settings > CI/CD > Runners**)
- Executor (`shell`, `docker`, ...)

### Cách không tương tác (non-interactive)

```bash
sudo gitlab-runner register \
  --non-interactive \
  --url "https://gitlab.example.com" \
  --token "<registration-token>" \
  --executor "shell" \
  --description "runner-shell-oracle"
```

## 3) Cài dependency thường dùng cho pipeline

### Java

```bash
sudo dnf install -y java-21-openjdk-devel
```

Nếu cần set `JAVA_HOME` cho user `gitlab-runner`:

```bash
sudo -u gitlab-runner bash -lc 'echo export JAVA_HOME=$(dirname $(dirname $(readlink -f $(which java)))) >> ~/.bash_profile'
```

### Docker (tuỳ chọn)

Xem thêm: `INSTALL-DOCKER.md`.

Nếu job build image Docker:

```bash
sudo usermod -aG docker gitlab-runner
sudo systemctl restart gitlab-runner
```

## 4) Xác minh

- Vào **Project > Settings > CI/CD > Runners**.
- Runner phải ở trạng thái `online`.

## Tài liệu chính thức

- https://docs.gitlab.com/runner/
