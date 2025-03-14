# Hướng dẫn Setup HA External ETCD

<!-- Mục lục -->
1. [Giới thiệu](#giới-thiệu)
2. [Kiến trúc](#kiến-trúc)
3. [Chuẩn bị môi trường](#chuẩn-bị-môi-trường)
4. [General certificate](#chuẩn-bị-môi-trường)
5. [Setup Loadbalance](#setup-loadbalance)
6. [Setup cluster ETCD](#setup-and-config-cluster-etcd)
7. [Setup Kubernetes](#setup-kubernetes)

---

## Giới thiệu

Hướng dẫn này mô tả cách thiết lập **High Availability (HA)** cho **Kubernetes** với **ETCD** dưới dạng External (ngoại vi).  
Bằng cách tách ETCD khỏi các node Master và triển khai nó thành một cluster độc lập, có thể đảm bảo tính sẵn sàng cao, cũng như tránh được rủi ro về “điểm chết” (single point of failure).

## Kiến trúc

Mô hình tổng thể:

- Triển khai một cluster ETCD riêng biệt gồm nhiều node (thường là **3** hoặc **5** node để đảm bảo **quorum**).
- Các node Kubernetes Master (control plane) sẽ trỏ đến ETCD cluster này.
- Nếu một node ETCD gặp sự cố, các node ETCD còn lại vẫn duy trì khả năng đọc/ghi dữ liệu, đảm bảo toàn hệ thống tiếp tục hoạt động ổn định.

```plaintex
    +-----------+        +-----------+
    | Master-01 |        | Master-02 |
    | (API Svr) |        | (API Svr) |
    +-----+-----+        +-----+-----+
          |                    |
       (Client)             (Client)
          |                    |
   +------+--------------------+------+
   |            ETCD CLUSTER          |
   |          (3 or 5 node HA)        |
   +----------------------------------+
```

## Chuẩn bị môi trường

|   hostname   |   IP Address  |   CPU  |  Ram   |       OS       |
|:------------:|:-------------:|:------:|:------:|:--------------:|
| master       | 192.168.56.31 |  2CPU  |   4G   | Oracle linux 9 |
| worker-01    | 192.168.56.51 |  2CPU  |   2G   | Oracle linux 9 |
| worker-02    | 192.168.56.52 |  2CPU  |   2G   | Oracle linux 9 |
| worker-03    | 192.168.56.53 |  2CPU  |   2G   | Oracle linux 9 |

---

## Setup Loadbalance

  ```bash
  # Cập nhật hệ thống và cài đặt HAProxy
  echo "[ SETUP AND SETTING HAPROXY ]"
  sudo setenforce 0
  sudo sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config
  sudo dnf update -y --quiet
  sudo dnf install -y --quiet haproxy
  sleep 2s

  echo "[ ENABLE HAPROXY TO AUTOMATICALLY START ON REBOOT ]"
  sudo systemctl enable --now haproxy

  echo "[ CONFIGURATION HAPROXY ]" 
  cat <<'EOF' | sudo tee /etc/haproxy/haproxy.cfg >/dev/null
  global
      # Send HAProxy logs to local syslog; adjust facility & level as needed
      log /dev/log local0 info
      maxconn 10000  # Adjust as appropriate

  defaults
      log global
      mode tcp
      option tcplog

      timeout connect 10s
      timeout client  10s
      timeout server  10s
      balance roundrobin
      retries 3

  # Frontend cho Kubernetes API Server
  frontend kubernetes-frontend
      bind *:6443
      default_backend kubernetes-backend

  # Backend cho Kubernetes API Server
  backend kubernetes-backend
      option tcp-check
      server master-01 192.168.56.31:6443 check
      server master-02 192.168.56.32:6443 check

  # Frontend cho NodePort Services
  frontend nodeport-frontend
      bind *:30000-35000
      default_backend nodeport-backend

  # Backend cho NodePort Services
  backend nodeport-backend
      server worker-01 192.168.56.51:30001
      server worker-02 192.168.56.52:30002
      server worker-03 192.168.56.53:30003
  EOF

  echo "[ CHECK STATUS HAPROXY ]" 
  sudo haproxy -c -f /etc/haproxy/haproxy.cfg
  sudo systemctl restart haproxy
  sudo systemctl status haproxy --no-pager
  ```

### Setup Kubernetes

- 1: Setup Kubernetes `192.168.56.31` `192.168.56.32` `192.168.56.51` `192.168.56.52` `192.168.56.53`

  ```bash
  #!/bin/bash

  echo "[ TURN OFF SWAP ]"
  sudo setenforce 0
  sudo swapoff -a
  sudo sed -i '/swap/s/^/#/' /etc/fstab
  sudo sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config

  echo "[ LOAD KERNEL MODULES ]"
  cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
  overlay
  br_netfilter
  EOF
  sudo modprobe overlay
  sudo modprobe br_netfilter

  echo "[ SET IP FORWARDING ]"
  cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
  net.ipv4.ip_forward = 1
  EOF
  sudo sysctl --system

  echo "[ INSTALLING CONTAINERD ]"
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

  echo "[ INSTALLING KUBERNETES ]"
  cat <<EOF | sudo tee /etc/yum.repos.d/kubernetes.repo
  [kubernetes]
  name=Kubernetes
  baseurl=https://pkgs.k8s.io/core:/stable:/v1.32/rpm/
  enabled=1
  gpgcheck=1
  gpgkey=https://pkgs.k8s.io/core:/stable:/v1.32/rpm/repodata/repomd.xml.key
  exclude=kubelet kubeadm kubectl cri-tools kubernetes-cni
  EOF
  sudo dnf install -y --quiet iproute-tc
  sudo dnf install -y --quiet kubelet kubeadm kubectl --disableexcludes=kubernetes
  sudo systemctl enable --now kubelet

  echo "[ CREATING DIRECTORY FOR ETCD ]"
  mkdir -vp /etcd/kubernetes/pki/etcd/

  cat <<EOF | sudo tee -a /etc/hosts
  192.168.56.31 master
  192.168.56.51 worker-01
  192.168.56.52 worker-02
  192.168.56.53 worker-03
  EOF
  ```

- 3: Initialize Kubernetes Cluster

  ```bash
  kubeadm init --config kubeadm-config.yml --upload-certs
  ```
  
  Sau chạy câu lệnh `kubeadm init --config kubeadm-config.yml --upload-certs` sẽ generate token để joi các node vào với nhau

  ```plaintex
  token dùng để join control-plane

  kubeadm join 192.168.56.11:6443 --token 9a08jv.*** --discovery-token-ca-cert-hash sha256:*** --control-plane --certificate-key ***

  token dùng để join worker-node

  kubeadm join 192.168.56.11:6443 --token 9a08jv.*** --discovery-token-ca-cert-hash sha256:***
  ```

  Cấu hình `kubectl`

  ```bash
  mkdir -p $HOME/.kube
  sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
  sudo chown $(id -u):$(id -g) $HOME/.kube/config
  ```

  Kiểm tra trạng thái

  ```plaintex
  kubectl get nodes

  NAME        STATUS      ROLES           AGE   VERSION
  master      NotReady    control-plane   16h   v1.32.1
  worker-01   NotReady    <none>          16h   v1.32.1
  worker-02   NotReady    <none>          16h   v1.32.1
  worker-03   NotReady    <none>          16h   v1.32.1
  ```

  Lúc này ta chưa seup network nên các node có trạng thái NotReady
  - trong ví dụ này tôi sẽ dùng mạng cilium

  ``` bash
  helm repo add cilium https://helm.cilium.io/
  helm repo update

  helm install cilium cilium/cilium --namespace kube-system --version 1.17.0
  ```

  - 4: kiểm tra lại các node

  ```plaintex
  NAME        STATUS      ROLES           AGE   VERSION
  master-01   Ready    control-plane   16h   v1.32.1
  worker-01   Ready    <none>          16h   v1.32.1
  worker-02   Ready    <none>          16h   v1.32.1
  worker-03   Ready    <none>          16h   v1.32.1
  ```
