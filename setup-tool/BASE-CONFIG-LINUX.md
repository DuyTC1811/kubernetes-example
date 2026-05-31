# BASE CONFIG SETUP LINUX
* CONFIG SSH
```bash
sudo nano /etc/ssh/sshd_config

# config timezone
sudo timedatectl set-timezone Asia/Ho_Chi_Minh
timedatectl
sudo timedatectl set-ntp true

```
* change
```txt
Port 22
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
```