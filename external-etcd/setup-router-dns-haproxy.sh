#!/usr/bin/env bash
set -euo pipefail

ROUTER_IP="192.168.122.19"
DOMAIN="lab.local"
CILIUM_GATEWAY_IP="192.168.122.200"
CILIUM_GATEWAY_PORT="80"

DNSMASQ_CONF="/etc/dnsmasq.d/lab-wildcard.conf"
HAPROXY_CFG="/etc/haproxy/haproxy.cfg"

echo "==> Installing packages..."
sudo apt update
sudo apt install -y dnsmasq haproxy dnsutils

echo "==> Backup old configs..."
if [[ -f "${DNSMASQ_CONF}" ]]; then
  sudo cp "${DNSMASQ_CONF}" "${DNSMASQ_CONF}.bak.$(date +%F-%H%M%S)"
fi

if [[ -f "${HAPROXY_CFG}" ]]; then
  sudo cp "${HAPROXY_CFG}" "${HAPROXY_CFG}.bak.$(date +%F-%H%M%S)"
fi

echo "==> Configuring dnsmasq wildcard DNS..."
sudo tee "${DNSMASQ_CONF}" >/dev/null <<EOF
# Wildcard DNS for internal Kubernetes Gateway lab
# All *.lab.local domains resolve to this router/HAProxy VM.
address=/${DOMAIN}/${ROUTER_IP}

listen-address=127.0.0.1,${ROUTER_IP}
bind-interfaces

no-resolv
server=8.8.8.8
server=1.1.1.1

domain-needed
bogus-priv
EOF

echo "==> Testing dnsmasq config..."
sudo dnsmasq --test

echo "==> Configuring HAProxy..."
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
    # headlamp.lab.local, argocd.lab.local, grafana.lab.local...
    option forwardfor
    http-request set-header X-Forwarded-Proto http
    http-request set-header X-Forwarded-Port 80

    default_backend cilium_gateway_http

backend cilium_gateway_http
    mode http

    # Forward tất cả HTTP traffic tới Cilium Gateway
    server cilium_gateway 192.168.122.200:80 check
EOF

echo "==> Checking HAProxy config..."
sudo haproxy -c -f "${HAPROXY_CFG}"

echo "==> Enable and restart services..."
sudo systemctl enable dnsmasq
sudo systemctl restart dnsmasq

sudo systemctl enable haproxy
sudo systemctl restart haproxy

echo "==> Open firewall ports if UFW is active..."
if command -v ufw >/dev/null 2>&1; then
  if sudo ufw status | grep -q "Status: active"; then
    sudo ufw allow from 192.168.122.0/24 to any port 53 proto udp
    sudo ufw allow from 192.168.122.0/24 to any port 53 proto tcp
    sudo ufw allow from 192.168.122.0/24 to any port 80 proto tcp
    sudo ufw reload
  fi
fi

echo
echo "==> Service status:"
sudo systemctl --no-pager --full status dnsmasq | sed -n '1,12p'
sudo systemctl --no-pager --full status haproxy | sed -n '1,12p'

echo
echo "==> DNS test:"
dig @${ROUTER_IP} headlamp.${DOMAIN} +short || true
dig @${ROUTER_IP} argocd.${DOMAIN} +short || true

echo
echo "==> HAProxy test:"
curl -I -H "Host: headlamp.${DOMAIN}" http://${ROUTER_IP} || true

echo
echo "Done."
echo "Configure client DNS server to: ${ROUTER_IP}"
echo "Then access: http://headlamp.${DOMAIN}"


# sudo apt install dnsmasq dnsutils -y