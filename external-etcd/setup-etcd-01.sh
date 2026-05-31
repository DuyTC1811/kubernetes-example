#!/bin/bash
set -xe

NODE_NAME="etcd-01"
NODE_IP="192.168.122.21"

ETCD_01_IP="192.168.122.21"
ETCD_02_IP="192.168.122.22"
ETCD_03_IP="192.168.122.23"

PKI_DIR="/etc/etcd/pki"
DATA_DIR="/var/lib/etcd/data"
WAL_DIR="/var/lib/etcd/wal"
LOG_DIR="/var/log/etcd"

# 1. Check certificate files
test -f "${PKI_DIR}/ca.pem"
test -f "${PKI_DIR}/etcd.pem"
test -f "${PKI_DIR}/etcd-key.pem"

# 2. Create required directories
sudo mkdir -p "${DATA_DIR}" "${WAL_DIR}" "${LOG_DIR}"

# 4. Create systemd service
cat <<EOF | sudo tee /etc/systemd/system/etcd.service > /dev/null
[Unit]
Description=etcd ${NODE_NAME}
Documentation=https://etcd.io/docs/
After=network-online.target
Wants=network-online.target

[Service]
Type=notify
ExecStart=/usr/local/bin/etcd \\
  --name ${NODE_NAME} \\
  --initial-advertise-peer-urls https://${NODE_IP}:2380 \\
  --listen-peer-urls https://${NODE_IP}:2380 \\
  --listen-client-urls https://${NODE_IP}:2379,https://127.0.0.1:2379 \\
  --advertise-client-urls https://${NODE_IP}:2379 \\
  --initial-cluster-token etcd-cluster-1 \\
  --initial-cluster etcd-01=https://${ETCD_01_IP}:2380,etcd-02=https://${ETCD_02_IP}:2380,etcd-03=https://${ETCD_03_IP}:2380 \\
  --initial-cluster-state new \\
  --snapshot-count 10000 \\
  --wal-dir ${WAL_DIR} \\
  --data-dir ${DATA_DIR} \\
  --log-outputs ${LOG_DIR}/etcd.log \\
  --client-cert-auth \\
  --trusted-ca-file ${PKI_DIR}/ca.pem \\
  --cert-file ${PKI_DIR}/etcd.pem \\
  --key-file ${PKI_DIR}/etcd-key.pem \\
  --peer-client-cert-auth \\
  --peer-trusted-ca-file ${PKI_DIR}/ca.pem \\
  --peer-cert-file ${PKI_DIR}/etcd.pem \\
  --peer-key-file ${PKI_DIR}/etcd-key.pem
Restart=on-failure
RestartSec=5
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

# 5. Start etcd
sudo systemctl daemon-reload
sudo systemctl enable etcd
sudo systemctl restart etcd

# sudo apt update
# sudo apt install -y ufw
# sudo ufw allow 22/tcp
# sudo ufw allow 2379/tcp
# sudo ufw allow 2380/tcp
# sudo ufw enable

#  XEM LOG
# sudo tail -n 200 -F /var/log/etcd/*.log
# etcdctl --cacert=/etc/etcd/pki/ca.pem --cert=/etc/etcd/pki/etcd.pem --key=/etc/etcd/pki/etcd-key.pem endpoint health -w=table --cluster
# etcdctl --cacert=/etc/etcd/pki/ca.pem --cert=/etc/etcd/pki/etcd.pem --key=/etc/etcd/pki/etcd-key.pem endpoint status -w=table --cluster
# etcdctl --cacert=/etc/etcd/pki/ca.pem --cert=/etc/etcd/pki/etcd.pem --key=/etc/etcd/pki/etcd-key.pem member list -w=table