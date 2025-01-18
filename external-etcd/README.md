# Hướng dẫn Setup HA External ETCD

<!-- Mục lục -->
1. [Giới thiệu](#giới-thiệu)
2. [Kiến trúc](#kiến-trúc)
3. [Chuẩn bị môi trường](#chuẩn-bị-môi-trường)
4. [Cài đặt và cấu hình cluster ETCD](#cài-đặt-và-cấu-hình-cluster-etcd)
    1. [Cài đặt ETCD](#1-cài-đặt-etcd)
    2. [Cấu hình ETCD HA](#2-cấu-hình-etcd-ha)
    3. [Kiểm tra hoạt động ETCD](#3-kiểm-tra-hoạt-động-etcd)
5. [Cấu hình Kubernetes Master trỏ tới ETCD](#cấu-hình-kubernetes-master-trỏ-tới-etcd)
6. [Kiểm tra và xác thực](#kiểm-tra-và-xác-thực)
7. [Tham khảo thêm](#tham-khảo-thêm)

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
1. **Hệ điều hành**: Phổ biến là Linux (Ubuntu/CentOS/RHEL/...).  
2. **Phiên bản Kubernetes**: Khuyến nghị từ Kubernetes 1.20 trở lên.
3. **Phần cứng**: Mỗi node trong ETCD cluster cần tài nguyên tối thiểu (VD: 2 CPU, 2GB RAM, dùng SSD nếu có thể).  
4. **Mạng**: Đảm bảo các node có thể kết nối với nhau qua cổng 2379 (cổng mặc định của ETCD) và 2380 (cổng peer).  
5. **Công cụ**:
   - **etcdctl**: công cụ quản trị ETCD.
   - **kubectl**: công cụ quản trị Kubernetes (trên node Master).

---

## Cài đặt và cấu hình cluster ETCD

### 1. Cài đặt ETCD
- Trên **mỗi node ETCD** (giả sử các node đặt tên là `etcd-01`, `etcd-02`, `etcd-03`):<br>
    > **Lưu ý**: Lệnh `sudo -i` dùng quyền cao nhất để cài đặt

    ```bash
    #!/bin/bash
    set -xe
    ETCD_VER=v3.5.17

    # Tắt Swap
    echo "---[ TURN OFF SWAP ]---"
    sudo swapoff -a
    sudo sed -i 's|^\(/swap\.img.*\)|# \1|' /etc/fstab

    #ETCD Version Setup
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

    # Kiểm tra phiên bản
    echo "[ STEP 5 ] --- [ CHECK VESION ]"
    etcd --version
    etcdctl version
    etcdutl version
    ```
### 2. Cấu hình ETCD HA

1. **Tạo thư mục chứa chứng chỉ**:<br>
    ```bash
    CERT_DIR="openssl"
    mkdir -p ${CERT_DIR}
    cd ${CERT_DIR}
    ```
2. **Tạo CA (Certificate Authority)**<br>
    ```bash
    openssl genrsa -out ca-key.pem 2048
    ```
    - **Mục đích:** Tạo khóa riêng (private key) cho CA, được lưu trong file ca-key.pem.<br>
    **Dung lượng khóa:** 2048-bit.
    ```bash
    openssl req -new -key ca-key.pem -out ca-csr.pem -subj "/C=VN/ST=Metri/L=Hanoi/O=example/CN=ca"
    ```
    - **Mục đích:** Tạo yêu cầu ký chứng chỉ (Certificate Signing Request, CSR) cho CA với thông tin:<br>
    - `C=VN:` Quốc gia (Vietnam).
    - `ST=Metri:` Bang/Tỉnh.
    - ``L=Hanoi:`` Thành phố.
    - ``O=example`` Tổ chức
    - ``CN=ca`` Tên thông thường (Common Name)
    ```bash
    openssl x509 -req -in ca-csr.pem -out ca.pem -days 3650 -signkey ca-key.pem -sha256
    ```
    - Ký chứng chỉ CA (self-signed certificate).
    - Chứng chỉ này có thời hạn 3650 ngày (~10 năm).
    - File kết quả: ca.pem là chứng chỉ gốc của CA.

3. **Tạo khóa riêng và CSR cho ETCD**
    ```bash
    openssl genrsa -out etcd-key.pem 2048
    ```
    - **Mục đích**: Tạo khóa riêng (private key) cho ETCD, được lưu trong file etcd-key.pem.
    ```bash
    openssl req -new -key etcd-key.pem -out etcd-csr.pem -subj "/C=VN/ST=Metri/L=Hanoi/O=example/CN=etcd"
    ```
4. **Tạo file cấu hình SAN (Subject Alternative Name)**
    ```bash
    echo "subjectAltName = DNS:localhost,IP:192.168.56.21,IP:192.168.56.22,IP:192.168.56.23,IP:127.0.0.1" > extfile.cnf
    ```
    - **Mục đích**: Xác định các tên miền (DNS) và địa chỉ IP hợp lệ cho chứng chỉ.
    - **File** `extfile.cnf` chứa thông tin SAN:
        - **DNS**: `localhost`.
        - **IP**: Các IP trong ETCD cluster (`192.168.56.21`, `192.168.56.22`, `192.168.56.23`) và `127.0.0.1`.

5. **Ký chứng chỉ ETCD với CA**
    ```bash
    openssl x509 -req -in etcd-csr.pem -CA ca.pem -CAkey ca-key.pem -CAcreateserial -days 3650 -out etcd.pem -sha256 -extfile extfile.cnf
    ```
    - **Mục đích:**
Ký chứng chỉ cho ETCD `(etcd.pem)` sử dụng chứng chỉ CA `(ca.pem)` và khóa riêng CA `(ca-key.pem).`
    - Thời hạn chứng chỉ: 3650 ngày (~10 năm).
    - **File đầu ra:**
        - `etcd.pem:` Chứng chỉ cho ETCD.
        - `ca.srl:` File serial được tạo tự động bởi `-CAcreateserial` (lưu trữ số serial của chứng chỉ).
6. **Hiển thị thông báo hoàn thành**
    ```bash
    echo "Certificates have been successfully created in the '${CERT_DIR}' directory."
    echo "Generated files:"
    echo "  - ca.pem        (CA certificate)"
    echo "  - ca-key.pem    (CA private key)"
    echo "  - etcd.pem      (etcd certificate)"
    echo "  - etcd-key.pem  (etcd private key)"
    echo "  - extfile.cnf   (SAN configuration)"
    ```