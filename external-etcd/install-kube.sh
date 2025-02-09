#!/bin/bash

echo "[ STEP 0 ] --- [ TURN OFF SWAP ]"
sudo setenforce 0
sudo swapoff -a
sudo sed -i 's|^\(/swap\.img.*\)|# \1|' /etc/fstab
sudo sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config

echo "[ STEP 1 ] --- [ LOAD KERNEL MODULES ]"
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF
sudo modprobe overlay
sudo modprobe br_netfilter

echo "[ STEP 2 ] --- [ SET IP FORWARDING ]"
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.ipv4.ip_forward = 1
EOF
sudo sysctl --system

echo "[ STEP 3 ] --- [ VERIFY THAT NET.IPV4.IP_FORWARD IS SET TO 1 ]"
sysctl net.ipv4.ip_forward

echo "[ STEP 4 ] --- [ INSTALLING CONTAINERD ]"
sudo dnf install -y --quiet dnf-plugins-core
sudo dnf config-manager --add-repo=https://download.docker.com/linux/centos/docker-ce.repo
sudo dnf install -y --quiet containerd.io
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
sudo sed -i 's|sandbox_image = ".*"|sandbox_image = "registry.k8s.io/pause:3.10"|' /etc/containerd/config.toml
grep "sandbox_image" /etc/containerd/config.toml
sudo systemctl restart containerd
sudo systemctl enable --now containerd
sudo systemctl status containerd

echo "[ STEP 5 ] --- [ INSTALLING KUBERNETES ]"
cat <<EOF | sudo tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://pkgs.k8s.io/core:/stable:/v1.32/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/v1.32/rpm/repodata/repomd.xml.key
exclude=kubelet kubeadm kubectl cri-tools kubernetes-cni
EOF

sudo dnf install -y --quiet kubelet kubeadm kubectl --disableexcludes=kubernetes
sudo systemctl enable --now kubelet

echo "[ STEP 7 ] --- [ CREATING DIRECTORY FOR ETCD ]"
mkdir -vp /etcd/kubernetes/pki/etcd/