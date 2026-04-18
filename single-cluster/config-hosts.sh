#!/bin/bash
set -euo pipefail

HOSTS_BLOCK_START="# BEGIN K8S-LAB-HOSTS"
HOSTS_BLOCK_END="# END K8S-LAB-HOSTS"

sudo sed -i "/${HOSTS_BLOCK_START}/,/${HOSTS_BLOCK_END}/d" /etc/hosts
cat <<EOF | sudo tee -a /etc/hosts >/dev/null
${HOSTS_BLOCK_START}
192.168.56.31 master.dns.local master-01
192.168.56.51 worker.dns.local worker-01
192.168.56.52 worker2.dns.local worker-02
${HOSTS_BLOCK_END}
EOF

echo "Updated /etc/hosts successfully."
