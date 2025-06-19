# Install Self-Managed GitLab on Oracle linux 8/9

This guide walks you through installing a self-managed GitLab instance using the official Linux package Oracle linux 8 or 9.

## Prerequisites

- Oracle linux (x86_64 or arm64)
- At least 4 GiB RAM
- Root or sudo privileges

---

## 1. Install Dependencies

```bash
sudo dnf install -y curl policycoreutils openssh-server perl
sudo systemctl enable sshd
sudo systemctl start sshd
sudo firewall-cmd --permanent --add-service=http
sudo firewall-cmd --permanent --add-service=https
sudo systemctl reload firewalld
```

### Config SMTP Gmail in GitLab

```bash
sudo nano /etc/gitlab/gitlab.rb
```
```bash
gitlab_rails['smtp_enable'] = true
gitlab_rails['smtp_address'] = "smtp.gmail.com"
gitlab_rails['smtp_port'] = 587
gitlab_rails['smtp_user_name'] = "your-gmail@gmail.com"
gitlab_rails['smtp_password'] = "app-password-16-chars"
gitlab_rails['smtp_domain'] = "smtp.gmail.com"
gitlab_rails['smtp_authentication'] = "login"
gitlab_rails['smtp_enable_starttls_auto'] = true
gitlab_rails['smtp_tls'] = false
gitlab_rails['gitlab_email_from'] = "your-gmail@gmail.com"

sudo gitlab-ctl reconfigure
```
> During installation, select `Internet Site` and enter your server's external DNS as the mail name.

---

## 2. Add GitLab Repository and Install

```bash
curl https://packages.gitlab.com/install/repositories/gitlab/gitlab-ce/script.rpm.sh | sudo bash
```

Replace `gitlab.example.com` with your server's domain or IP:

```bash
sudo EXTERNAL_URL="https://gitlab.example.com" dnf install -y gitlab-ce
```
- For available versions:  
    `sudo dnf --showduplicates list gitlab-ee`
- To install a specific version:  
    `sudo dnf install gitlab-ee-<version>`

---

## 3. Access GitLab

- Open `https://gitlab.example.com` in your browser.
- The initial root password is stored in `cat /etc/gitlab/initial_root_password` (valid for 24 hours).
- Login with username `root` and the password above.

---

## 4. Next Steps

- [Configure authentication and sign-up restrictions](https://docs.gitlab.com/ee/security/)
- [Set up communication preferences](https://about.gitlab.com/company/updates/email-preferences/)
- [Review reference architecture](https://docs.gitlab.com/ee/administration/reference_architectures/)

---

## Troubleshooting

- [Official troubleshooting guide](https://docs.gitlab.com/ee/administration/troubleshooting/)
- For manual installation (CE or EE), see [GitLab downloads](https://about.gitlab.com/install/)

---

**References:**
- [GitLab Omnibus Documentation](https://docs.gitlab.com/omnibus/)
- [Supported distributions and versions](https://docs.gitlab.com/ee/install/requirements.html)