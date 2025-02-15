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
| etcd-01      | 192.168.56.21 |  2CPU  |   2G   | Oracle linux 9 |
| etcd-02      | 192.168.56.22 |  2CPU  |   2G   | Oracle linux 9 |
| etcd-03      | 192.168.56.23 |  2CPU  |   2G   | Oracle linux 9 |
| master-01    | 192.168.56.31 |  2CPU  |   4G   | Oracle linux 9 |
| master-02    | 192.168.56.32 |  2CPU  |   4G   | Oracle linux 9 |
| worker-01    | 192.168.56.51 |  2CPU  |   2G   | Oracle linux 9 |
| worker-02    | 192.168.56.52 |  2CPU  |   2G   | Oracle linux 9 |
| worker-03    | 192.168.56.53 |  2CPU  |   2G   | Oracle linux 9 |
| loadbalancer | 192.168.56.11 |  2CPU  |   2G   | Oracle linux 9 |

---

## General certificate

1. **Tạo thư mục chứa chứng chỉ ở máy local của bạn**:

    ```bash
    CERT_DIR="openssl"
    mkdir -p ${CERT_DIR} && cd ${CERT_DIR}

    # 1. Tạo khóa riêng (private key) và chứng chỉ CA (Certificate Authority)
    echo ">>> CREATING CA KEY AND CERTIFICATE..."
    openssl genrsa -out ca-key.pem 2048
    openssl req -new -key ca-key.pem -out ca-csr.pem -subj "/C=VN/ST=Metri/L=Hanoi/O=example/CN=ca"
    openssl x509 -req -in ca-csr.pem -out ca.pem -days 3650 -signkey ca-key.pem -sha256

    # 2. Tạo khóa riêng và yêu cầu ký chứng chỉ (CSR) cho etcd
    echo ">>> CREATING ETCD KEY AND CSR..."
    openssl genrsa -out etcd-key.pem 2048
    openssl req -new -key etcd-key.pem -out etcd-csr.pem -subj "/C=VN/ST=Metri/L=Hanoi/O=example/CN=etcd"

    # 3. Tạo file cấu hình mở rộng cho Subject Alternative Name (SAN)
    echo ">>> CREATING SAN CONFIGURATION..."
    cat <<EOF > extfile.cnf
    subjectAltName = DNS:localhost,IP:192.168.56.21,IP:192.168.56.22,IP:192.168.56.23,IP:127.0.0.1
    EOF

    # 4. Ký chứng chỉ etcd với CA
    echo ">>> SIGNING ETCD CERTIFICATE WITH CA..."
    openssl x509 -req -in etcd-csr.pem -CA ca.pem -CAkey ca-key.pem -CAcreateserial -days 3650 -out etcd.pem -sha256 -extfile extfile.cnf

    # 5. Hiển thị thông báo hoàn thành và danh sách tệp được tạo
    echo ">>> Certificates have been successfully created in the '${CERT_DIR}' directory."
    ls -l

    ```

      > **NOTE:** Tạo yêu cầu ký chứng chỉ (CSR) với thông tin như:
          >>- `C=VN`: Quốc gia (Vietnam).
          >>- `ST=Metri`: Bang/Tỉnh.
          >>- `L=Hanoi`: Thành phố.
          >>- `O=example`: Tổ chức.
          >>- `CN=ca`: Tên thông thường (Common Name).
          >>- `-days 3650`: Thời hạn (~10 năm).

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

## Setup and config cluster ETCD

- 1: Setup ETCD

  ```bash
  echo "[ TURN OFF SELINUX ]"
  sudo setenforce 0
  sudo sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config
  echo "ETCD VERSION: ${ETCD_VER}"

  # choose either URL
  GOOGLE_URL=https://storage.googleapis.com/etcd
  GITHUB_URL=https://github.com/etcd-io/etcd/releases/download
  DOWNLOAD_URL=${GOOGLE_URL}

  echo "[ CLEAN UP AND PREPARE TEMPORARY FOLDER ]"
  sudo rm -f /tmp/etcd-${ETCD_VER}-linux-amd64.tar.gz
  sudo rm -rf /tmp/etcd-download-test && mkdir -p /tmp/etcd-download-test

  echo "[ DOWNLOAD AND UNZIP ETCD ]"
  curl -L ${DOWNLOAD_URL}/${ETCD_VER}/etcd-${ETCD_VER}-linux-amd64.tar.gz -o /tmp/etcd-${ETCD_VER}-linux-amd64.tar.gz
  tar xzvf /tmp/etcd-${ETCD_VER}-linux-amd64.tar.gz -C /tmp/etcd-download-test --strip-components=1
  sudo rm -f /tmp/etcd-${ETCD_VER}-linux-amd64.tar.gz

  echo "[ STEP 3 ] --- [ MOVE EXECUTABLE FILES TO SYSTEM FOLDER ]"
  sudo mv -v /tmp/etcd-download-test/etcd /usr/local/bin
  sudo mv -v /tmp/etcd-download-test/etcdctl /usr/local/bin
  sudo mv -v /tmp/etcd-download-test/etcdutl /usr/local/bin

  echo "[ DELETE TEMPORARY FOLDER ]"
  sudo rm -rf /tmp/etcd-download-test
  mkdir -p /var/lib/etcd
  ```

  > **NOTE:** Setup:
  > (etcd-01) `192.168.56.21`
  > (etcd-02) `192.168.56.22`
  > (etcd-03) `192.168.56.23`

- 2: Sao chép chứng chỉ đến các node

    ```bash
    scp -i ~/.ssh/id_rsa ca.pem etcd.pem etcd-key.pem root@192.168.56.21:/var/lib/etcd
    scp -i ~/.ssh/id_rsa ca.pem etcd.pem etcd-key.pem root@192.168.56.22:/var/lib/etcd
    scp -i ~/.ssh/id_rsa ca.pem etcd.pem etcd-key.pem root@192.168.56.23:/var/lib/etcd
    ```

  > Note:`~/.ssh/id_rsa`: Đường dẫn tới private key `root@192.168.56.x`: Địa chỉ IP `/var/lib/etcd`: Thư mục trên node.

- 3:**Tạo file** `etcd.service` (etcd-01) `192.168.56.21` (etcd-01) `192.168.56.22` (etcd-01) `192.168.56.23`:
  > Note: thay thế `--name` `--initial-advertise-peer-urls` `--listen-peer-urls` `--listen-client-urls` `--advertise-client-urls` Tương ứng mỗi node

    ```bash
    cat <<EOF > /etc/systemd/system/etcd.service
        [Unit]
        Description=etcd
        [Service]
        ExecStart=/usr/local/bin/etcd \\
        --name etcd-01 \\                                            # Tên của node trong cụm etcd
        --initial-advertise-peer-urls https://192.168.56.21:2380 \\  # URL để cho biết các node khác có thể kết nối qua Ip này
        --listen-peer-urls https://192.168.56.21:2380 \\             # URL để lắng nghe kết nối từ các node khác trong cụm
        --listen-client-urls https://192.168.56.21:2379,https://127.0.0.1:2379 \\ # URL để lắng nghe các kết nối từ client
        --advertise-client-urls https://192.168.56.21:2379 \\        # URL quảng cáo cho client kết nối
        --initial-cluster-token etcd-token \\                        # Token nhận diện cụm etcd
        # Danh sách các node trong cụm và địa chỉ peer
        --initial-cluster etcd-01=https://192.168.56.21:2380,etcd-02=https://192.168.56.22:2380,etcd-03=https://192.168.56.23:2380 \\
        --log-outputs=/var/lib/etcd/etcd.log \\                      # File log của etcd
        --initial-cluster-state new \\                               # Trạng thái ban đầu của cụm (new/existing)
        --peer-auto-tls \\                                           # Kích hoạt tự động tạo TLS giữa các node trong cụm
        --snapshot-count '10000' \\                                  # Số lượng thay đổi trước khi tạo snapshot
        --wal-dir=/var/lib/etcd/wal \\                               # Thư mục lưu trữ WAL (Write-Ahead Log)
        --client-cert-auth \\                                        # Kích hoạt xác thực client bằng chứng chỉ
        --trusted-ca-file=/var/lib/etcd/ca.pem \\                    # File CA dùng để xác thực client
        --cert-file=/var/lib/etcd/etcd.pem \\                        # File chứng chỉ của etcd server
        --key-file=/var/lib/etcd/etcd-key.pem \\                     # File khóa riêng của etcd server
        --data-dir=/var/lib/etcd/data                                # Thư mục lưu trữ dữ liệu của etcd
        Restart=on-failure                                           # Tự động khởi động lại nếu service gặp lỗi
        RestartSec=5                                                 # Thời gian chờ trước khi khởi động lại (5 giây)

        [Install]
        WantedBy=multi-user.target                                   # Dịch vụ sẽ được khởi động trong chế độ multi-user (chế độ server)
        EOF
        sudo systemctl daemon-reload
        sudo systemctl enable etcd
        sudo systemctl start etcd
    ```

- 4: Kiểm tra hoạt động ETCD

    ```bash
    etcdctl --cacert=/var/lib/etcd/ca.pem --cert=/var/lib/etcd/etcd.pem --key=/var/lib/etcd/etcd-key.pem endpoint health -w=table --cluster
    ```

    ```plaintex
    +----------------------------+--------+------------+-------+
    |          ENDPOINT          | HEALTH |    TOOK    | ERROR |
    +----------------------------+--------+------------+-------+
    | https://192.168.56.21:2379 |   true | 6.781673ms |       |
    | https://192.168.56.23:2379 |   true | 5.884019ms |       |
    | https://192.168.56.22:2379 |   true |  7.83654ms |       |
    +----------------------------+--------+------------+-------+
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
  192.168.56.31 master-01
  192.168.56.32 master-02
  192.168.56.51 worker-01
  192.168.56.52 worker-02
  192.168.56.53 worker-03
  192.168.56.11 loadbalancer
  EOF
  ```

- 2: Sao chép chứng chỉ đến các node master

    ```bash
    scp -i ../../.ssh/id_rsa.pub ca.pem etcd.pem etcd-key.pem root@192.168.56.31:/etcd/kubernetes/pki/etcd
    scp -i ../../.ssh/id_rsa.pub ca.pem etcd.pem etcd-key.pem root@192.168.56.32:/etcd/kubernetes/pki/etcd
    ```

- 3: Tạo file cấu hình Node master: `sudo touch kubeadm-config.yaml`

  ```yaml
  apiVersion: kubeadm.k8s.io/v1beta4
  kind: InitConfiguration
  bootstrapTokens:
    - token: "9a08jv.c0izixklcxtmnze7"
      description: "kubeadm bootstrap token"
      ttl: "24h"
    - token: "783bde.3f89s0fje9f38fhf"
      description: "another bootstrap token"
      usages:
        - authentication
        - signing
      groups:
        - system:bootstrappers:kubeadm:default-node-token

  nodeRegistration:
    name: "master-01"
    criSocket: "unix:///var/run/containerd/containerd.sock"
    taints: []
    ignorePreflightErrors:
      - IsPrivilegedUser
    imagePullPolicy: "IfNotPresent"

  localAPIEndpoint:
    advertiseAddress: "192.168.56.31" # Địa chỉ IP của server control plane
    bindPort: 6443                    # Cổng mặc định API server

  certificateKey: "dd40f915bfbd850963f212b793ba1da8c2f89307d5b0e25c7cd7705b94da0b01" # Được lấy từ "kubeadm certs certificate-key"

  # skipPhases:
  #   - preflight       # Bỏ qua kiểm tra ban đầu
  #   - kubelet-start   # Không khởi động kubelet
  #   - certs           # Bỏ qua tạo chứng chỉ

  timeouts:
    controlPlaneComponentHealthCheck: "60s" # Chờ 120 giây kiểm tra thành phần control plane

  ---
  apiVersion: kubeadm.k8s.io/v1beta4
  kind: ClusterConfiguration

  etcd:
    external:
      endpoints:
        - "https://192.168.56.21:2379"
        - "https://192.168.56.22:2379"
        - "https://192.168.56.23:2379"
      caFile: "/etcd/kubernetes/pki/etcd/ca.pem"
      certFile: "/etcd/kubernetes/pki/etcd/etcd.pem"
      keyFile: "/etcd/kubernetes/pki/etcd/etcd-key.pem"

  networking:
    serviceSubnet: "10.96.0.0/16"  # Dải địa chỉ cho ClusterIP Services
    podSubnet: "192.168.0.0/16"    # Dải địa chỉ cho Pods, tùy chỉnh theo yêu cầu
    dnsDomain: "cluster.local"     # Tên miền DNS nội bộ

  kubernetesVersion: "v1.32.0"

  # Thay giá trị này bằng IP và cổng của LoadBalancer/Public IP OR Private IP
  controlPlaneEndpoint: "192.168.56.11:6443"

  apiServer:
    # Bổ sung thêm các SANs để API Server trust địa chỉ IP Public, v.v.
    certSANs:
      - "loadbalancer"
      - "master-02"
      - "worker-01"
      - "worker-02"
      - "worker-03"
      - "127.0.0.1"
  controllerManager: {}
  scheduler: {}

  certificatesDir: "/etc/kubernetes/pki"        # Thư mục lưu chứng chỉ TLS
  imageRepository: "registry.k8s.io"            # Registry chính thức để tải image Kubernetes
  clusterName: "dev-master"                     # Tên cluster (nên thay đổi phù hợp)
  encryptionAlgorithm: ECDSA-P256               # Thuật toán mã hóa TLS (khuyến nghị)

  dns:
    disabled: true  # disable CoreDNS
  proxy:
    disabled: true   # disable kube-proxy
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
  master-01   NotReady    control-plane   16h   v1.32.1
  master-2    NotReady    control-plane   16h   v1.32.1
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
  master-2    Ready    control-plane   16h   v1.32.1
  worker-01   Ready    <none>          16h   v1.32.1
  worker-02   Ready    <none>          16h   v1.32.1
  worker-03   Ready    <none>          16h   v1.32.1
  ```
