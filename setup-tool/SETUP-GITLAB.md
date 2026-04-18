# Cài Self-Managed GitLab trên Oracle Linux 8/9

## 1) Điều kiện

- Oracle Linux 8/9
- Tối thiểu 4 GB RAM (khuyến nghị cao hơn cho production)
- Quyền `sudo`

## 2) Cài dependency hệ thống

```bash
sudo dnf install -y curl policycoreutils openssh-server perl
sudo systemctl enable --now sshd
sudo firewall-cmd --permanent --add-service=http
sudo firewall-cmd --permanent --add-service=https
sudo systemctl reload firewalld
```

## 3) Cài GitLab package

```bash
curl https://packages.gitlab.com/install/repositories/gitlab/gitlab-ce/script.rpm.sh | sudo bash
sudo EXTERNAL_URL="https://gitlab.example.com" dnf install -y gitlab-ce
```

> Đổi `gitlab.example.com` thành domain/IP thực tế của bạn.

## 4) Lấy mật khẩu root ban đầu

```bash
sudo cat /etc/gitlab/initial_root_password
```

Thông tin này có hiệu lực trong khoảng 24 giờ sau cài đặt.

## 5) (Tuỳ chọn) Cấu hình SMTP Gmail

Sửa file:

```bash
sudo nano /etc/gitlab/gitlab.rb
```

Thêm/chỉnh:

```ruby
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
```

Áp dụng cấu hình:

```bash
sudo gitlab-ctl reconfigure
```

## 6) Tài liệu tham khảo

- https://docs.gitlab.com/omnibus/
- https://docs.gitlab.com/ee/install/requirements.html
- https://docs.gitlab.com/ee/administration/troubleshooting/
