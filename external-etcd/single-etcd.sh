#!/bin/bash
set -xe
cat <<EOF > /etc/systemd/system/etcd.service
[Unit]
Description=etcd - single node cluster
Documentation=https://etcd.io/docs/
After=network.target

[Service]
ExecStart=/usr/local/bin/etcd \
  --name etcd-01 \
  --initial-advertise-peer-urls=https://192.168.1.11:2380 \
  --listen-peer-urls=https://192.168.1.11:2380 \
  --listen-client-urls=https://192.168.1.11:2379,https://127.0.0.1:2379 \
  --advertise-client-urls=https://192.168.1.11:2379 \
  --initial-cluster-token=etcd-cluster-1 \
  --initial-cluster=etcd-01=https://192.168.1.11:2380 \
  --initial-cluster-state=new \
  --data-dir=/var/lib/etcd/data \
  --wal-dir=/var/lib/etcd/wal \
  --snapshot-count=10000 \
  --log-outputs=/var/lib/etcd/etcd.log \
  --peer-auto-tls \
  --client-cert-auth \
  --trusted-ca-file=/var/lib/etcd/ca.pem \
  --cert-file=/var/lib/etcd/etcd.pem \
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