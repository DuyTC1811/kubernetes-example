#!/bin/bash
set -e  # Dừng script nếu có lỗi
set -u  # Dừng nếu sử dụng biến chưa được khai báo

# Tạo thư mục chứa chứng chỉ
CERT_DIR="openssl"
mkdir -p ${CERT_DIR}
cd ${CERT_DIR}

# 1. Tạo CA key và CA certificate
echo "CREATING CLIENT KEY AND CERTIFICATE..."
openssl genrsa -out ca-key.pem 2048
openssl req -new -key ca-key.pem -out ca-csr.pem -subj "/CN=etcd cluster"
openssl req -new -key ca-key.pem -out ca-csr.pem -subj "/C=VN/ST=Metri/L=Hanoi/O=example/CN=ca"
openssl x509 -req -in ca-csr.pem -out ca.pem -days 3650 -signkey ca-key.pem -sha256

# 2. Tạo etcd key và certificate signing request (CSR)
echo "CREATING ETCD KEY AND CSR..."
openssl genrsa -out etcd-key.pem 2048
openssl req -new -key etcd-key.pem -out etcd-csr.pem -subj "/C=VN/ST=Metri/L=Hanoi/O=example/CN=etcd"

# 3. Tạo file cấu hình mở rộng cho Subject Alternative Name (SAN)
echo "subjectAltName = DNS:localhost,IP:192.168.56.21,IP:192.168.56.22,IP:192.168.56.23,IP:127.0.0.1" > extfile.cnf

# 4. Tạo etcd certificate với CA
echo "Signing etcd certificate with CA..."
openssl x509 -req -in etcd-csr.pem -CA ca.pem -CAkey ca-key.pem -CAcreateserial -days 3650 -out etcd.pem -sha256 -extfile extfile.cnf

# 5. Hiển thị thông báo hoàn thành
echo "Certificates have been successfully created in the '${CERT_DIR}' directory."
echo "Generated files:"
echo "  - ca.pem        (CA certificate)"
echo "  - ca-key.pem    (CA private key)"
echo "  - etcd.pem      (etcd certificate)"
echo "  - etcd-key.pem  (etcd private key)"
echo "  - extfile.cnf   (SAN configuration)"
ls -l "${CERT_DIR}"


# scp -i ../../.ssh/id_rsa.pub ca.pem etcd.pem etcd-key.pem root@192.168.56.21:/var/lib/etcd
# scp -i ../../.ssh/id_rsa.pub ca.pem etcd.pem etcd-key.pem root@192.168.56.22:/var/lib/etcd
# scp -i ../../.ssh/id_rsa.pub ca.pem etcd.pem etcd-key.pem root@192.168.56.23:/var/lib/etcd

# scp -i ../../.ssh/id_rsa.pub ca.pem etcd.pem etcd-key.pem root@192.168.56.31:/etcd/kubernetes/pki/etcd
# scp -i ../../.ssh/id_rsa.pub ca.pem etcd.pem etcd-key.pem root@192.168.56.32:/etcd/kubernetes/pki/etcd