#!/bin/bash
set -e  # Dừng script nếu có lỗi
set -u  # Dừng nếu sử dụng biến chưa được khai báo

# Tạo thư mục chứa chứng chỉ
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


# scp -i ../../.ssh/id_rsa.pub ca.pem etcd.pem etcd-key.pem root@192.168.56.21:/var/lib/etcd
# scp -i ../../.ssh/id_rsa.pub ca.pem etcd.pem etcd-key.pem root@192.168.56.22:/var/lib/etcd
# scp -i ../../.ssh/id_rsa.pub ca.pem etcd.pem etcd-key.pem root@192.168.56.23:/var/lib/etcd

# scp -i ../../.ssh/id_rsa.pub ca.pem etcd.pem etcd-key.pem root@192.168.56.31:/etcd/kubernetes/pki/etcd
# scp -i ../../.ssh/id_rsa.pub ca.pem etcd.pem etcd-key.pem root@192.168.56.32:/etcd/kubernetes/pki/etcd