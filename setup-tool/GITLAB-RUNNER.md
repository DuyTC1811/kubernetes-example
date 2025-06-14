# Setting Up GitLab Runner

This guide explains how to set up a GitLab Runner for your CI/CD pipelines.

## Prerequisites

- A GitLab account
- Access to your GitLab project
- A server or VM (Linux, macOS, or Windows) with Docker installed

## 1. Install GitLab Runner

**On Linux (using Docker):**
```sh
docker run -d --name gitlab-runner --restart always \
    -v /srv/gitlab-runner/config:/etc/gitlab-runner \
    -v /var/run/docker.sock:/var/run/docker.sock \
    gitlab/gitlab-runner:latest
```

**Or, install directly:**
```sh
curl -L https://packages.gitlab.com/install/repositories/runner/gitlab-runner/script.deb.sh | sudo bash
sudo apt-get install gitlab-runner
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
## 3. Start the Runner

```sh
sudo gitlab-runner start
```

## 4. Verify Runner

Go to your GitLab project’s **Settings > CI/CD > Runners** to confirm the runner is active.

## References

- [GitLab Runner Docs](https://docs.gitlab.com/runner/)