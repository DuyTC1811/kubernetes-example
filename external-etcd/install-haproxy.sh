#!/bin/bash
set -xe

sudo apt update
sudo apt install haproxy -y
sleep 2s
sudo systemctl start haproxy && sudo systemctl enable haproxy

sudo bash -c 'cat <<EOF | sudo tee /etc/haproxy/haproxy.cfg
# Frontend cho Kubernetes API Server
frontend kubernetes-frontend
  bind *:6443
  mode tcp
  option tcplog
  timeout client 10s
  log global
  default_backend kubernetes-backend

# Backend cho Kubernetes API Server
backend kubernetes-backend
  mode tcp
  timeout connect 10s
  timeout server 10s
  option tcp-check
  balance roundrobin

  server master-01 192.168.56.31:6443 check
  server master-02 192.168.56.32:6443 check

# Frontend cho NodePort Services
frontend nodeport-frontend
  bind *:30000-35000
  mode tcp
  option tcplog
  timeout client 10s
  log global
  default_backend nodeport-backend

# Backend cho NodePort Services
backend nodeport-backend
  mode tcp
  timeout connect 10s
  timeout server 10s
  balance roundrobin

  server worker-01 192.168.56.51
  server worker-02 192.168.56.52
  server worker-03 192.168.56.53
EOF'
sudo systemctl restart haproxy
