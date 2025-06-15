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
    # local2.*  /var/log/haproxy.log
    log         127.0.0.1 local2

    chroot	    /var/lib/haproxy
    pidfile     /var/run/haproxy.pid
    maxconn     4000
    user        haproxy
    group	    haproxy
    daemon

    # turn on stats unix socket
    stats socket /var/lib/haproxy/stats

#---------------------------------------------------------------------
# common defaults that all the 'listen' and 'backend' sections will
# use if not designated in their block
#---------------------------------------------------------------------
defaults
    mode                    tcp
    log                     global
    option                  tcplog
    retries                 3
    timeout connect         10s
    timeout client          1m
    timeout server          1m

#---------------------------------------------------------------------
# main frontend which proxys to the backends
#---------------------------------------------------------------------
frontend main
    bind *:6443
    default_backend             kubernetes-backend

# Backend cho Kubernetes API Server
backend kubernetes-backend
    option tcp-check
    balance roundrobin
    server master-01 192.168.1.14:6443 check
    server master-02 192.168.1.15:6443 check
EOF

echo "[ CHECK STATUS HAPROXY ]" 
sudo haproxy -c -f /etc/haproxy/haproxy.cfg
sudo systemctl restart haproxy
sudo systemctl status haproxy --no-pager
