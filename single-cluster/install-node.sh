#!/bin/bash

echo "[ STEP 1 ] ---[ TURN OFF SWAP ]"
sudo swapoff -a
sed -ri '/\sswap\s/s/^#?/#/' /etc/fstab

echo "[ STEP 2 ] --- [ SET IP FORWARDING ]"
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.ipv4.ip_forward = 1
EOF
sudo sysctl --system

echo "[ STEP 3 ] --- [ VERIFY THAT NET.IPV4.IP_FORWARD IS SET TO 1 WITH ]"
sysctl net.ipv4.ip_forward

echo "[ STEP 3 ] --- [ INSTALLING CONTAINERD RUNTIME USING DOCKER ]"
sudo apt-get update -qq
sudo apt-get install -qq -y apt-transport-https ca-certificates curl gpg socat
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc
echo \
"deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
$(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update -qq
sudo apt-get install -qq -y containerd.io
containerd config default > /etc/containerd/config.toml
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
sudo systemctl restart containerd

echo "[ STEP 4 ] --- [ INSTALLING KUBERNETES ]"
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.31/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.31/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo apt-get update -qq
sudo apt-get install -qq -y kubelet kubeadm kubectl

echo "[ STEP 5 ] --- [ AND PIN THEIR VERSION ]"
sudo apt-mark hold kubelet kubeadm kubectl