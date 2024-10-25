#!/bin/bash

echo "====================> [ TURN OFF SWAP ] <===================="
sudo swapoff -a
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

echo "==================> [ SET IP FORWARDING ] <=================="
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.ipv4.ip_forward = 1
EOF

echo "=================> [ APPLY SYSCTL PARAMS ] <================="
sudo sysctl --system

echo "==> [ VERIFY THAT NET.IPV4.IP_FORWARD IS SET TO 1 WITH ] <==="
sysctl net.ipv4.ip_forward

echo "=============> [ ADD DOCKER'S OFFICIAL GPG KEY ] <==========="
sudo apt-get update
sudo apt-get install -y ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

echo "==========> [ ADD THE REPOSITORY TO APT SOURCES ] <=========="
echo \
"deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
$(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update

echo "======> [ INSTALLING CONTAINERD RUNTIME USING DOCKER ] <======"
sudo apt-get install -y containerd.io
containerd config default > /etc/containerd/config.toml
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
sudo systemctl restart containerd
sudo apt-get update

echo ">[ INSTALLING APT-TRANSPORT-HTTPS CA-CERTIFICATES CURL GPG ]<"
sudo apt-get install -y apt-transport-https ca-certificates curl gpg socat

echo "===>[ DOWNLOAD THE PUBLIC SIGNING KEY FOR THE KUBERNETES ]<=="
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.31/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo "=============>[ APPLY CONFIGURATION KUBERNETES ]<============"
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.31/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list

echo "=============>[ APPLY CONFIGURATION KUBERNETES ]<============"
sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl

echo "=================>[ AND PIN THEIR VERSION ]<================="
sudo apt-mark hold kubelet kubeadm kubectl