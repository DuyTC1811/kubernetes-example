#!/bin/bash
set -euo pipefail

echo "[ SETUP HAPROXY ON DEBIAN ]"

sudo apt update
sudo apt install -y haproxy
echo "[ CONFIGURE UFW ]"

# Allow SSH trước để tránh mất kết nối
sudo apt install -y ufw
sudo ufw allow OpenSSH
# Allow HAProxy Stats UI
sudo ufw allow 8404/tcp
# Allow Kubernetes API Load Balancer
sudo ufw allow 6443/tcp
# Enable UFW không hỏi y/n
sudo ufw --force enable

echo "[ CONFIGURE HAPROXY ]"
cat <<'EOF' | sudo tee /etc/haproxy/haproxy.cfg >/dev/null
global
    log /dev/log local0
    log /dev/log local1 notice
    chroot /var/lib/haproxy
    stats socket /run/haproxy/admin.sock mode 660 level admin expose-fd listeners
    stats timeout 30s
    user haproxy
    group haproxy
    daemon
    maxconn 4000

defaults
    log global
    mode tcp
    option tcplog
    option dontlognull
    retries 3
    timeout connect 10s
    timeout client 1m
    timeout server 1m

frontend k8s-api
    bind *:6443
    mode tcp
    default_backend kubernetes-backend

backend kubernetes-backend
    mode tcp
    balance roundrobin
    option tcp-check
    default-server inter 3s fall 3 rise 2
    server master-01 192.168.122.31:6443 check
    server master-02 192.168.122.32:6443 check

listen stats
    bind *:8404
    mode http
    stats enable
    stats uri /stats
    stats refresh 10s
    stats show-legends
    stats auth admin:admin123
EOF

echo "[ CHECK HAPROXY CONFIG ]"
sudo haproxy -c -f /etc/haproxy/haproxy.cfg

echo "[ ENABLE AND RESTART HAPROXY ]"
sudo systemctl enable haproxy
sudo systemctl restart haproxy

echo "[ CHECK HAPROXY STATUS ]"
sudo systemctl status haproxy --no-pager

# http://192.168.122.20:8404/stats
#  XEM LOG
# sudo journalctl -u haproxy -f

# sudo ufw allow 80/tcp
# sudo ufw reload
# sudo ufw status