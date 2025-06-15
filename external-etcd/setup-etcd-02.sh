#!/bin/bash
set -xe
cat <<EOF > /etc/systemd/system/etcd.service
[Unit]
Description=etcd-02
Documentation=https://etcd.io/docs/
After=network.target

[Service]
ExecStart=/usr/local/bin/etcd \\
  --name etcd-02 \\
  --initial-advertise-peer-urls https://192.168.56.22:2380 \\
  --listen-peer-urls https://192.168.56.22:2380 \\
  --listen-client-urls https://192.168.56.22:2379,https://127.0.0.1:2379 \\
  --advertise-client-urls https://192.168.56.22:2379 \\
  --initial-cluster-token etcd-cluster-1 \\
  --initial-cluster etcd-01=https://192.168.56.21:2380,etcd-02=https://192.168.56.22:2380,etcd-03=https://192.168.56.23:2380 \\
  --log-outputs=/var/lib/etcd/etcd.log \\
  --initial-cluster-state new \\
  --peer-auto-tls \\
  --snapshot-count '10000' \\
  --wal-dir=/var/lib/etcd/wal \\
  --data-dir=/var/lib/etcd/data \\
  --client-cert-auth \\
  --trusted-ca-file=/var/lib/etcd/ca.pem \\
  --cert-file=/var/lib/etcd/etcd.pem \\
  --key-file=/var/lib/etcd/etcd-key.pem
Restart=on-failure
RestartSec=5
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF
sudo systemctl daemon-reload
sudo systemctl enable etcd
sudo systemctl start etcd

# etcdctl --cacert=/var/lib/etcd/ca.pem --cert=/var/lib/etcd/etcd.pem --key=/var/lib/etcd/etcd-key.pem endpoint health -w=table --cluster
# etcdctl --cacert=/var/lib/etcd/ca.pem --cert=/var/lib/etcd/etcd.pem --key=/var/lib/etcd/etcd-key.pem endpoint status -w=table --cluster
# etcdctl --cacert=/var/lib/etcd/ca.pem --cert=/var/lib/etcd/etcd.pem --key=/var/lib/etcd/etcd-key.pem member list -w=table