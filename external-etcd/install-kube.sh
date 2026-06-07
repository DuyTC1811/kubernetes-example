#!/bin/bash
set -euo pipefail

K8S_VERSION="v1.36"

echo "[ TURN OFF SWAP ]"
sudo swapoff -a
sudo sed -i.bak '/[[:space:]]swap[[:space:]]/ s/^/#/' /etc/fstab

echo "[ LOAD KERNEL MODULES ]"
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf >/dev/null
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter

echo "[ SET SYSCTL FOR KUBERNETES ]"
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf >/dev/null
net.ipv4.ip_forward = 1
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF

sudo sysctl --system

echo "[ INSTALL CONTAINERD ]"
sudo apt-get install -y containerd

echo "[ CONFIGURE CONTAINERD ]"
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml >/dev/null
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
sudo sed -i 's|bin_dir = "/usr/lib/cni"|bin_dir = "/opt/cni/bin"|' /etc/containerd/config.toml
sudo sed -i 's|sandbox_image = ".*"|sandbox_image = "registry.k8s.io/pause:3.10"|' /etc/containerd/config.toml
grep "SystemdCgroup" /etc/containerd/config.toml
grep "sandbox_image" /etc/containerd/config.toml
sudo systemctl restart containerd
sudo systemctl enable --now containerd

sleep 2

if sudo systemctl is-active --quiet containerd; then
  echo "containerd is running"
else
  echo "ERROR: containerd is not running"
  sudo journalctl -u containerd --no-pager -n 100
  exit 1
fi

echo "[ INSTALL KUBERNETES ]"
sudo apt-get update
sudo mkdir -p /etc/apt/keyrings
sudo apt-get install -y apt-transport-https ca-certificates curl gpg
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.36/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.36/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl

echo "[ CREATE ETCD PKI DIRECTORY ]"
sudo mkdir -p /etc/etcd/pki
sudo chown root:root /etc/etcd/pki
sudo chmod 700 /etc/etcd/pki

echo "[ DONE ]"
echo "Kubernetes node preparation completed."
echo "Next step: run kubeadm init on control-plane or kubeadm join on worker."

sudo sed -i 's|bin_dir = "/usr/lib/cni"|bin_dir = "/opt/cni/bin"|' /etc/containerd/config.toml
sudo grep -n "bin_dir\|conf_dir" /etc/containerd/config.toml
sudo systemctl restart containerd
