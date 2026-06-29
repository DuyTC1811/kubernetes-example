#!/usr/bin/env bash
set -euo pipefail

HOSTNAME_NEW="router"
STATIC_IP="192.168.122.19/24"
GATEWAY_IP="192.168.122.1"
DNS_SERVERS="8.8.8.8 1.1.1.1"

IFACE="$(ip route | awk '/default/ {print $5; exit}')"

if [[ -z "${IFACE}" ]]; then
  echo "ERROR: Cannot detect default interface"
  exit 1
fi

echo "Detected interface: ${IFACE}"

hostnamectl set-hostname "${HOSTNAME_NEW}"

if grep -q '^127.0.1.1' /etc/hosts; then
  sed -i "s/^127.0.1.1.*/127.0.1.1 ${HOSTNAME_NEW}/" /etc/hosts
else
  echo "127.0.1.1 ${HOSTNAME_NEW}" >> /etc/hosts
fi

mkdir -p /etc/systemd/network/backup

if ls /etc/systemd/network/*.network >/dev/null 2>&1; then
  cp /etc/systemd/network/*.network /etc/systemd/network/backup/
fi

cat > "/etc/systemd/network/10-${IFACE}.network" <<EOF
[Match]
Name=${IFACE}

[Network]
Address=${STATIC_IP}
Gateway=${GATEWAY_IP}
DNS=${DNS_SERVERS}
EOF

systemctl enable systemd-networkd
systemctl restart systemd-networkd

echo "Done."
hostnamectl --static
ip -4 addr show "${IFACE}"
ip route