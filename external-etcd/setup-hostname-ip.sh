#!/usr/bin/env bash
set -euo pipefail

# ===== Config node =====
NODE_HOSTNAME="etcd-02"
STATIC_IP="192.168.122.22"
INTERFACE="enp1s0"

# ===== Network config =====
GATEWAY="192.168.122.1"
DNS1="8.8.8.8"
DNS2="1.1.1.1"
DOMAIN="lab.local"

# ===== etcd nodes =====
ETCD1_IP="192.168.122.21"
ETCD2_IP="192.168.122.22"
ETCD3_IP="192.168.122.23"

if [[ "$EUID" -ne 0 ]]; then
  echo "ERROR: Please run as root or use sudo"
  exit 1
fi

echo "==> Checking interface: ${INTERFACE}"
if ! ip link show "${INTERFACE}" >/dev/null 2>&1; then
  echo "ERROR: Interface ${INTERFACE} not found"
  echo "Available interfaces:"
  ip -br link
  exit 1
fi

echo "==> Set hostname to ${NODE_HOSTNAME}"
hostnamectl set-hostname "${NODE_HOSTNAME}"

echo "==> Create systemd-networkd config"
mkdir -p /etc/systemd/network

cat > "/etc/systemd/network/10-${INTERFACE}-static.network" <<EOF
[Match]
Name=${INTERFACE}

[Network]
DHCP=no
Address=${STATIC_IP}/24
DNS=${DNS1}
DNS=${DNS2}
Domains=${DOMAIN}

[Route]
Gateway=${GATEWAY}
PreferredSource=${STATIC_IP}
EOF

echo "==> Update /etc/hosts"
cat > /etc/hosts <<EOF
127.0.0.1       localhost
127.0.1.1       ${NODE_HOSTNAME}.${DOMAIN} ${NODE_HOSTNAME}

${ETCD1_IP} etcd-01.${DOMAIN} etcd-01
${ETCD2_IP} etcd-02.${DOMAIN} etcd-02
${ETCD3_IP} etcd-03.${DOMAIN} etcd-03
EOF

echo "==> Disable NetworkManager if exists"
if systemctl list-unit-files | grep -q '^NetworkManager.service'; then
  systemctl disable --now NetworkManager || true
fi

echo "==> Disable ifupdown networking.service if exists"
if systemctl list-unit-files | grep -q '^networking.service'; then
  systemctl disable --now networking || true
fi

echo "==> Enable systemd-networkd"
systemctl enable --now systemd-networkd

echo "==> Remove old dynamic IPv4 addresses from ${INTERFACE}"
for ip in $(ip -4 -o addr show dev "${INTERFACE}" scope global dynamic | awk '{print $4}'); do
  echo "Removing dynamic IP: ${ip}"
  ip addr del "${ip}" dev "${INTERFACE}" || true
done

echo "==> Restart systemd-networkd"
systemctl restart systemd-networkd

sleep 2

echo
echo "==> Result"
echo "Hostname:"
hostname

echo
echo "FQDN:"
hostname -f || true

echo
echo "IP:"
ip -br addr show "${INTERFACE}"

echo
echo "Route:"
ip route

echo
echo "Reconnect SSH using:"
echo "ssh debian@${STATIC_IP}"

# touch setup-hotname.sh
# chmod +x setup-hotname.sh
# touch install-etcd.sh
# chmod +x install-etcd.sh
# touch setup-etcd.sh
# chmod +x setup-etcd.sh