sudo apt-get update
sudo apt-get install haproxy -y

cat <<EOF | sudo tee /etc/haproxy/haproxy.cfg
frontend kubernetes-frontend
  bind *:6443
  mode tcp
  default_backend kubernetes-backend

backend kubernetes-backend
  mode tcp
  balance roundrobin
  server control-plane-1 192.168.56.31:6443 check
  server control-plane-2 192.168.56.32:6443 check
EOF
sudo systemctl restart haproxy
