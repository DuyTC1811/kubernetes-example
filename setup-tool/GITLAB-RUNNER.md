# Setting Up GitLab Runner

This guide explains how to set up a GitLab Runner for your CI/CD pipelines.

## Prerequisites

- A GitLab account
- Access to your GitLab project
- A server or VM (Oracle linux 9)

## 1. Install GitLab Runner
```sh
curl -L "https://packages.gitlab.com/install/repositories/runner/gitlab-runner/script.rpm.sh" | sudo bash
sudo dnf -y install gitlab-runner
sudo systemctl enable gitlab-runner
sudo systemctl start gitlab-runner
```

## 2. Register the Runner

```sh
sudo gitlab-runner register
```
- Enter your GitLab instance URL.
- Enter the registration token (find it in your project under **Settings > CI/CD > Runners**).
- Enter a description and tags (optional).
- Choose the executor (e.g., `docker`, `shell`, etc.).
- or install 
```bash
sudo gitlab-runner register \
  --non-interactive \
  --url "http://192.168.1.21" \
  --token "glrt-liWyjoxswR7KU0HnAykxZG86MQpwOjEKdDozCnU6Mg8.01.171qmiqgo" \
  --executor "shell" \
  --description "runner-shell-oracle-192.168.1.21"
```
## 3. Install JAVA
Thiết lập JAVA_HOME cho user gitlab-runner hoặc  nodejs hay package khác 
```sh
sudo dnf install java-21-openjdk-devel -y
# sudo nano /home/gitlab-runner/.bash_profile
# tự động set JAVA_HOME đúng với phiên bản Java hiện tại:
export JAVA_HOME=$(dirname $(dirname $(readlink -f $(which java))))
```

## 3. Install Docker
- [Install Docker](INSTALL-DOCKER.md)
```sh
# permissions docker build images and push
sudo usermod -aG docker gitlab-runner # grant 
```

## 4. Verify Runner

Go to your GitLab project’s **Settings > CI/CD > Runners** to confirm the runner is active.

## References

- [GitLab Runner Docs](https://docs.gitlab.com/runner/)