#!/bin/bash
set -xe

# Cập nhật hệ thống và cài đặt HAProxy
echo "[ SETUP AND SETTING HAPROXY ]"
sudo setenforce 0
sudo sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config
sudo dnf update -y --quiet
sudo dnf install -y --quiet haproxy
sleep 2s

echo "[ ENABLE HAPROXY TO AUTOMATICALLY START ON REBOOT ]"
sudo systemctl enable --now haproxy

echo "[ CONFIGURATION HAPROXY ]" 
cat <<'EOF' | sudo tee /etc/haproxy/haproxy.cfg >/dev/null
global
    # Send HAProxy logs to local syslog; adjust facility & level as needed
    log /dev/log local0 info
    maxconn 10000  # Adjust as appropriate

defaults
    log global
    mode tcp
    option tcplog

    timeout connect 10s
    timeout client  10s
    timeout server  10s
    balance roundrobin
    retries 3

# Frontend cho Kubernetes API Server
frontend kubernetes-frontend
    bind *:6443
    default_backend kubernetes-backend

# Backend cho Kubernetes API Server
backend kubernetes-backend
    option tcp-check
    server master-01 192.168.56.31:6443 check
    server master-02 192.168.56.32:6443 check

# Frontend cho NodePort Services
frontend nodeport-frontend
    bind *:30000-35000
    default_backend nodeport-backend

# Backend cho NodePort Services
backend nodeport-backend
    server worker-01 192.168.56.51
    server worker-02 192.168.56.52
    server worker-03 192.168.56.53
EOF

echo "[ CHECK STATUS HAPROXY ]" 
sudo haproxy -c -f /etc/haproxy/haproxy.cfg
sudo systemctl restart haproxy
sudo systemctl status haproxy --no-pager
