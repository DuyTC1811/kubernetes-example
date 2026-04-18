#!/bin/bash
set -euo pipefail

HOSTS_BLOCK_START="# BEGIN EXTERNAL-ETCD-HOSTS"
HOSTS_BLOCK_END="# END EXTERNAL-ETCD-HOSTS"

sudo sed -i "/${HOSTS_BLOCK_START}/,/${HOSTS_BLOCK_END}/d" /etc/hosts
cat <<EOF | sudo tee -a /etc/hosts >/dev/null
${HOSTS_BLOCK_START}
192.168.56.21 etcd-01
192.168.56.22 etcd-02
192.168.56.23 etcd-03
192.168.56.31 master-01
192.168.56.32 master-02
192.168.56.51 worker-01
192.168.56.52 worker-02
192.168.56.53 worker-03
192.168.56.11 loadbalancer
${HOSTS_BLOCK_END}
EOF

echo "Updated /etc/hosts successfully."
