# Hướng dẫn Setup HA External ETCD

<!-- Mục lục -->
1. [Giới thiệu](#giới-thiệu)
2. [Kiến trúc](#kiến-trúc)
3. [Chuẩn bị môi trường](#chuẩn-bị-môi-trường)
4. [Cài đặt và cấu hình cluster ETCD](#cài-đặt-và-cấu-hình-cluster-etcd)
    1. [Cài đặt ETCD](#1-cài-đặt-etcd)
    2. [Cấu hình ETCD HA](#2-cấu-hình-etcd-ha)
    3. [Kiểm tra hoạt động ETCD](#3-kiểm-tra-hoạt-động-etcd)
5. [Cấu hình Kubernetes Master trỏ tới ETCD](#5-cấu-hình-kubernetes-master-trỏ-tới-etcd)
    1. [Cài Kubernetes](#1-cài-kubernetes)
    2. [Config HAProxy](#2-config-haproxy)
    3. [Config Kubeadm](#3-config-kubeadm)
6. [Kiểm tra và xác thực](#bước-4-kiểm-tra-trạng-thái)

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

|     Name     |       IP      |   CPU  |  Ram   |     OS     |
|:------------:|:-------------:|:------:|:------:|:----------:|
| etcd-01      | 192.168.56.21 |  2CPU  |   2G   | CentOS 9   |
| etcd-02      | 192.168.56.22 |  2CPU  |   2G   | CentOS 9   |
| etcd-03      | 192.168.56.23 |  2CPU  |   2G   | CentOS 9   |
| master-01    | 192.168.56.31 |  2CPU  |   4G   | CentOS 9   |
| master-02    | 192.168.56.32 |  2CPU  |   4G   | CentOS 9   |
| worker-01    | 192.168.56.51 |  2CPU  |   2G   | CentOS 9   |
| worker-02    | 192.168.56.52 |  2CPU  |   2G   | CentOS 9   |
| worker-03    | 192.168.56.53 |  2CPU  |   2G   | CentOS 9   |
| loadbalancer | 192.168.56.11 |  2CPU  |   2G   | CentOS 9   |

---

## Cài đặt và cấu hình cluster ETCD

### 1. Cài đặt ETCD

- Trên **mỗi node ETCD** (giả sử các node đặt tên là `etcd-01`, `etcd-02`, `etcd-03`)

    ```bash
    #!/bin/bash
    set -xe
    ETCD_VER=v3.5.17

    # Tắt Swap
    echo "---[ TURN OFF SWAP ]---"
    sudo setenforce 0
    sudo swapoff -a
    sudo sed -i 's|^\(/swap\.img.*\)|# \1|' /etc/fstab
    sudo sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config

    echo "ETCD VERSION: ${ETCD_VER}"

    # choose either URL
    GOOGLE_URL=https://storage.googleapis.com/etcd
    GITHUB_URL=https://github.com/etcd-io/etcd/releases/download
    DOWNLOAD_URL=${GOOGLE_URL}

    # Chuẩn bị thư mục tạm thời
    echo "[ STEP 1 ] --- [ CLEAN UP AND PREPARE TEMPORARY FOLDER ]"
    sudo rm -f /tmp/etcd-${ETCD_VER}-linux-amd64.tar.gz
    sudo rm -rf /tmp/etcd-download-test && mkdir -p /tmp/etcd-download-test

    # Tải xuống và giải nén ETCD
    echo "[ STEP 2 ] --- [ DOWNLOAD AND UNZIP ETCD ]"
    curl -L ${DOWNLOAD_URL}/${ETCD_VER}/etcd-${ETCD_VER}-linux-amd64.tar.gz -o /tmp/etcd-${ETCD_VER}-linux-amd64.tar.gz
    tar xzvf /tmp/etcd-${ETCD_VER}-linux-amd64.tar.gz -C /tmp/etcd-download-test --strip-components=1
    sudo rm -f /tmp/etcd-${ETCD_VER}-linux-amd64.tar.gz

    # Di chuyển file thực thi vào thư mục hệ thống
    echo "[ STEP 3 ] --- [ MOVE EXECUTABLE FILES TO SYSTEM FOLDER ]"
    sudo mv -v /tmp/etcd-download-test/etcd /usr/local/bin
    sudo mv -v /tmp/etcd-download-test/etcdctl /usr/local/bin
    sudo mv -v /tmp/etcd-download-test/etcdutl /usr/local/bin

    # Xoá thư mục tạm
    echo "[ STEP 4 ] --- [ DELETE TEMPORARY FOLDER ]"
    sudo rm -rf /tmp/etcd-download-test
    mkdir -p /var/lib/etcd
    ```

- Check kiểm tra version

    ```bash
    etcd --version
    etcdctl version
    ```

### 2. Cấu hình ETCD HA

1. **Tạo thư mục chứa chứng chỉ**:

    ```bash
    CERT_DIR="openssl"
    mkdir -p ${CERT_DIR}
    cd ${CERT_DIR}
    ```

2. **Tạo CA (Certificate Authority)**:
    - Tạo khóa riêng cho CA:

        ```bash
        openssl genrsa -out ca-key.pem 2048
        ```

        - **Mục đích:** Tạo khóa riêng (private key) cho CA, được lưu trong file `ca-key.pem`.
        - **Dung lượng khóa:** 2048-bit.

    - Tạo yêu cầu ký chứng chỉ (CSR) cho CA:

        ```bash
        openssl req -new -key ca-key.pem -out ca-csr.pem -subj "/C=VN/ST=Metri/L=Hanoi/O=example/CN=ca"
        ```

        - **Mục đích:** Tạo yêu cầu ký chứng chỉ (CSR) với thông tin như:
            - `C=VN`: Quốc gia (Vietnam).
            - `ST=Metri`: Bang/Tỉnh.
            - `L=Hanoi`: Thành phố.
            - `O=example`: Tổ chức.
            - `CN=ca`: Tên thông thường (Common Name).

    - Ký chứng chỉ CA (self-signed):

        ```bash
        openssl x509 -req -in ca-csr.pem -out ca.pem -days 3650 -signkey ca-key.pem -sha256
        ```

        - **Mục đích:** Ký chứng chỉ cho CA.
        - **Thời hạn:** 3650 ngày (~10 năm).
        - **Kết quả:** Tạo file chứng chỉ CA `ca.pem`.

3. **Tạo khóa riêng và CSR cho ETCD**:
    - Tạo khóa riêng cho ETCD:

        ```bash
        openssl genrsa -out etcd-key.pem 2048
        ```

        - **Mục đích:** Tạo khóa riêng (private key) cho ETCD.

    - Tạo yêu cầu ký chứng chỉ (CSR) cho ETCD:

        ```bash
        openssl req -new -key etcd-key.pem -out etcd-csr.pem -subj "/C=VN/ST=Metri/L=Hanoi/O=example/CN=etcd"
        ```

4. **Tạo file cấu hình SAN (Subject Alternative Name)**:

    ```bash
    echo "subjectAltName = DNS:localhost,IP:192.168.56.21,IP:192.168.56.22,IP:192.168.56.23,IP:127.0.0.1" > extfile.cnf
    ```

    - **Mục đích:** Xác định các tên miền (DNS) và địa chỉ IP hợp lệ cho chứng chỉ.
    - **Nội dung SAN:**
        - **DNS:** `localhost`.
        - **IP:** `192.168.56.21`, `192.168.56.22`, `192.168.56.23`, `127.0.0.1`.

5. **Ký chứng chỉ ETCD với CA**:

    ```bash
    openssl x509 -req -in etcd-csr.pem -CA ca.pem -CAkey ca-key.pem -CAcreateserial -days 3650 -out etcd.pem -sha256 -extfile extfile.cnf
    ```

    - **Mục đích:** Ký chứng chỉ cho ETCD (`etcd.pem`) bằng CA (`ca.pem` và `ca-key.pem`).
    - **Thời hạn:** 3650 ngày (~10 năm).
    - **File kết quả:**
        - `etcd.pem`: Chứng chỉ ETCD.
        - `ca.srl`: File serial lưu số serial của chứng chỉ.

6. **Hiển thị thông báo hoàn thành**:

    ```bash
    echo "Certificates have been successfully created in the '${CERT_DIR}' directory."
    echo "Generated files:"
    echo "  - ca.pem        (CA certificate)"
    echo "  - ca-key.pem    (CA private key)"
    echo "  - etcd.pem      (etcd certificate)"
    echo "  - etcd-key.pem  (etcd private key)"
    echo "  - extfile.cnf   (SAN configuration)"
    ls -l "${CERT_DIR}"
    ```

7. **Sao chép chứng chỉ đến các node**:

    ```bash
    scp -i ~/.ssh/id_rsa ca.pem etcd.pem etcd-key.pem root@192.168.56.21:/var/lib/etcd
    scp -i ~/.ssh/id_rsa ca.pem etcd.pem etcd-key.pem root@192.168.56.22:/var/lib/etcd
    scp -i ~/.ssh/id_rsa ca.pem etcd.pem etcd-key.pem root@192.168.56.23:/var/lib/etcd
    ```

    - **Giải thích:**
        - `~/.ssh/id_rsa`: Đường dẫn tới private key để kết nối qua SSH.
        - `root@192.168.56.x`: Địa chỉ IP của các node ETCD.
        - `/var/lib/etcd`: Thư mục trên node từ xa để lưu chứng chỉ.

8. **Tạo file `etcd.service` trên mỗi node**:
    - Tạo file `/etc/systemd/system/etcd.service`:

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
            --initial-cluster-token etcd-cluster-1 \\                    # Token nhận diện cụm etcd
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

   ## 3. Kiểm tra hoạt động ETCD

    ```bash
    sudo etcdctl --cacert=/var/lib/etcd/ca.pem --cert=/var/lib/etcd/etcd.pem --key=/var/lib/etcd/etcd-key.pem endpoint health -w=table --cluster
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

## 5. Cấu hình Kubernetes Master trỏ tới ETCD

## 1. Cài Kubernetes

### Bước 1: Cài đặt các gói cần thiết

```bash
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
```

### Bước 2: Đặt tên hostname

```bash
sudo bash -c 'cat <<EOF >>/etc/hosts
192.168.56.31 master-01
192.168.56.32 master-02
192.168.56.51 worker-01
192.168.56.52 worker-02
192.168.56.53 worker-03
192.168.56.11 loadbalancer
EOF'
reboot
```

## 2. Config HAProxy

### Bước 1: Cài đặt HAProxy

- tạo file `install-haproxy.sh`

  ```bash
  sudo touch install-haproxy.sh chmod +x install-haproxy.sh
  ```

  ```bash
  #!/bin/bash
  set -xe

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

## 3. Config Kubeadm

### Bước 1: Tạo file cấu hình Node master

Tạo file với nội dung như sau: `sudo touch kubeadm-config.yaml`

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
  extraArgs:
    - name: authorization-mode
      value: Node,RBAC

  # Bổ sung thêm các SANs để API Server trust địa chỉ IP Public, v.v.
  certSANs:
    - "192.168.56.31"               # Địa chỉ IP Private của server
    - "master-01"                   # Tên DNS hoặc hostname
    - "192.168.56.11"               # Public IP Loadbalance (nếu cần kết nối từ ngoài)
    - "127.0.0.1"                   # Loopback để kiểm tra nội bộ

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

---
apiVersion: kubelet.config.k8s.io/v1beta1
kind: KubeletConfiguration
# kubelet specific options here
# (Giữ nguyên hoặc tuỳ chỉnh theo nhu cầu)

---
apiVersion: kubeproxy.config.k8s.io/v1alpha1
kind: KubeProxyConfiguration
# kube-proxy specific options here
# (Giữ nguyên hoặc tuỳ chỉnh theo nhu cầu)

```

### Bước 2: Initialize Kubernetes Cluster

```bash
kubeadm init --config kubeadm-config.yml --upload-certs
```

```plaintex
kubeadm join 192.168.56.11:6443 --token 9a08jv.c0izixklcxtmnze7 \
      --discovery-token-ca-cert-hash sha256:5e7d23aae85f344b2f042e4b975d3f5f14f1f460252f12de4a8a4bcd1abac3c6 \
      --control-plane --certificate-key 10fc6bdd3cd8b4dd8cc1daf6937c9a02cf345055ef949654ce8e38d486298a8a

kubeadm join 192.168.56.11:6443 --token 9a08jv.c0izixklcxtmnze7 \
        --discovery-token-ca-cert-hash sha256:5e7d23aae85f344b2f042e4b975d3f5f14f1f460252f12de4a8a4bcd1abac3c6 
```

### Bước 3: Cấu hình `kubectl`

```bash
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

### Bước 4: Kiểm tra trạng thái

```bash
kubectl get nodes
kubectl get pods -A
```

---
Hoàn thành quá trình cấu hình Kubernetes Master trỏ tới ETCD.
