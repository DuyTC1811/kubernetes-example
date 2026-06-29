#!/usr/bin/env bash
set -euo pipefail

CILIUM_GATEWAY_IP="192.168.122.200"
CILIUM_GATEWAY_HTTP_PORT="80"
HAPROXY_CFG="/etc/haproxy/haproxy.cfg"

echo "==> Installing HAProxy..."
sudo apt update
sudo apt install -y haproxy

echo "==> Backup old HAProxy config..."
if [[ -f "${HAPROXY_CFG}" ]]; then
  sudo cp "${HAPROXY_CFG}" "${HAPROXY_CFG}.bak.$(date +%F-%H%M%S)"
fi

echo "==> Writing HAProxy config for Cilium Gateway..."

sudo tee "${HAPROXY_CFG}" >/dev/null <<EOF
global
    log /dev/log local0
    log /dev/log local1 notice
    chroot /var/lib/haproxy
    stats socket /run/haproxy/admin.sock mode 660 level admin
    stats timeout 30s
    user haproxy
    group haproxy
    daemon

defaults
    log global
    mode http
    option httplog
    option dontlognull

    timeout connect 5s
    timeout client  60s
    timeout server  60s

frontend http_frontend
    bind *:80
    mode http

    # Giữ nguyên Host header từ client:
    # headlamp.local, argocd.local, grafana.local...
    # Không set Host cố định ở HAProxy.

    option forwardfor
    http-request set-header X-Forwarded-Proto http
    http-request set-header X-Forwarded-Port 80

    default_backend cilium_gateway_http

backend cilium_gateway_http
    mode http

    # Health check đơn giản tới Cilium Gateway.
    # Lưu ý: nếu Gateway yêu cầu Host cụ thể, health check có thể trả 404 nhưng traffic vẫn chạy.
    # Có thể bỏ check nếu backend bị DOWN do Host mismatch.
    server cilium_gateway ${CILIUM_GATEWAY_IP}:${CILIUM_GATEWAY_HTTP_PORT} check
EOF

echo "==> Checking HAProxy config..."
sudo haproxy -c -f "${HAPROXY_CFG}"

echo "==> Enabling and restarting HAProxy..."
sudo systemctl enable haproxy
sudo systemctl restart haproxy

echo "==> HAProxy status:"
sudo systemctl --no-pager status haproxy

echo
echo "==> Done."