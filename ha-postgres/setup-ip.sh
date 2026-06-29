#!/bin/bash
set -euo pipefail

# CONFIG
HOSTNAME_NEW="db-standby-02"

INTERFACE="enp1s0"
STATIC_IP="192.168.122.141/24"
GATEWAY="192.168.122.1"

DNS1="8.8.8.8"
DNS2="1.1.1.1"

NETWORK_FILE="/etc/systemd/network/10-static-${INTERFACE}.network"

# CHECK ROOT
if [ "$EUID" -ne 0 ]; then
  echo "ERROR: Please run as root"
  echo "Example: sudo ./setup-network.sh"
  exit 1
fi

# CHECK INTERFACE
if ! ip link show "$INTERFACE" >/dev/null 2>&1; then
  echo "ERROR: Interface $INTERFACE not found"
  echo "Available interfaces:"
  ip -o link show | awk -F': ' '{print $2}'
  exit 1
fi

echo "================================"
echo "Setup hostname and static IP"
echo "================================"
echo "Hostname : $HOSTNAME_NEW"
echo "Interface: $INTERFACE"
echo "IP       : $STATIC_IP"
echo "Gateway  : $GATEWAY"
echo "DNS      : $DNS1, $DNS2"
echo "================================"

# SET HOSTNAME
echo
echo "=== Set hostname ==="

hostnamectl set-hostname "$HOSTNAME_NEW"

cat > /etc/hosts <<EOF
127.0.0.1       localhost
127.0.1.1       $HOSTNAME_NEW

::1             localhost ip6-localhost ip6-loopback
ff02::1         ip6-allnodes
ff02::2         ip6-allrouters
EOF

# DISABLE CONFLICT SERVICES
echo
echo "=== Disable conflicting network services if exists ==="

systemctl disable NetworkManager 2>/dev/null || true
systemctl disable networking 2>/dev/null || true
systemctl disable dhcpcd 2>/dev/null || true

# ENABLE SYSTEMD-NETWORKD
echo
echo "=== Enable systemd-networkd and systemd-resolved ==="

systemctl enable systemd-networkd

# REMOVE OLD NETWORKD CONFIG FOR THIS INTERFACE
echo
echo "=== Remove old systemd-networkd config for this interface ==="

rm -f /etc/systemd/network/*"${INTERFACE}"*.network

# CREATE STATIC NETWORK CONFIG
echo
echo "=== Write static IP config ==="

cat > "$NETWORK_FILE" <<EOF
[Match]
Name=$INTERFACE

[Network]
Address=$STATIC_IP
Gateway=$GATEWAY
DNS=$DNS1
DNS=$DNS2
IPv6AcceptRA=no
LinkLocalAddressing=no
EOF

# SET DNS RESOLVER
echo
echo "=== Setup DNS resolver ==="

ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf

# RESTART SERVICES
echo
echo "=== Restart network services ==="

systemctl restart systemd-networkd

# SHOW RESULT
echo
echo "================================"
echo "RESULT"
echo "================================"

echo
echo "Hostname:"
hostnamectl --static

echo
echo "Network config file:"
cat "$NETWORK_FILE"

echo
echo "IP address:"
ip -4 addr show "$INTERFACE"

echo
echo "Route:"
ip route

echo
echo "Networkd status:"
networkctl status "$INTERFACE" --no-pager || true

echo
echo "DONE."
echo "Please reboot server to apply static IP:"
echo
echo "sudo reboot"