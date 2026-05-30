#!/bin/bash
set -euo pipefail

# =========================
# Config
# =========================
CERT_DIR="openssl"
REMOTE_USER="debian"
REMOTE_CERT_DIR="/etc/etcd/pki"

ETCD_SERVERS=(
  "192.168.122.21"
  "192.168.122.22"
  "192.168.122.23"
)

# =========================
# Prepare directory
# =========================
mkdir -p "${CERT_DIR}"
sudo chown -R "$(whoami):$(whoami)" "${CERT_DIR}"

cd "${CERT_DIR}"

echo ">>> CLEAN OLD CERTIFICATES..."
rm -f ca-key.pem ca.pem ca.srl \
      etcd-key.pem etcd.pem etcd.csr \
      ca.cnf etcd-ext.cnf

# =========================
# Create valid CA certificate
# =========================
echo ">>> CREATING CA CONFIG..."

cat > ca.cnf <<EOF
[req]
distinguished_name = req_distinguished_name
x509_extensions = v3_ca
prompt = no

[req_distinguished_name]
C = VN
ST = Metri
L = Hanoi
O = example
CN = etcd-ca

[v3_ca]
basicConstraints = critical, CA:TRUE
keyUsage = critical, keyCertSign, cRLSign
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always,issuer
EOF

echo ">>> CREATING CA KEY AND CERTIFICATE..."

openssl genrsa -out ca-key.pem 4096

openssl req -x509 \
  -new \
  -nodes \
  -key ca-key.pem \
  -sha256 \
  -days 3650 \
  -out ca.pem \
  -config ca.cnf

echo ">>> CHECK CA CERTIFICATE..."
openssl x509 -in ca.pem -text -noout | grep -A5 "Basic Constraints"

# =========================
# Create etcd certificate
# =========================
echo ">>> CREATING ETCD CERT EXTENSION CONFIG..."

cat > etcd-ext.cnf <<EOF
[ v3_req ]
basicConstraints = CA:FALSE
keyUsage = critical, digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth, clientAuth
subjectAltName = @alt_names

[ alt_names ]
DNS.1 = localhost
DNS.2 = etcd-01
DNS.3 = etcd-02
DNS.4 = etcd-03
DNS.5 = etcd-01.lab.local
DNS.6 = etcd-02.lab.local
DNS.7 = etcd-03.lab.local
IP.1 = 127.0.0.1
IP.2 = 192.168.122.21
IP.3 = 192.168.122.22
IP.4 = 192.168.122.23
EOF

echo ">>> CREATING ETCD KEY AND CSR..."

openssl genrsa -out etcd-key.pem 4096

openssl req -new \
  -key etcd-key.pem \
  -out etcd.csr \
  -subj "/C=VN/ST=Metri/L=Hanoi/O=example/CN=etcd"

echo ">>> SIGNING ETCD CERTIFICATE WITH CA..."

openssl x509 -req \
  -in etcd.csr \
  -CA ca.pem \
  -CAkey ca-key.pem \
  -CAcreateserial \
  -out etcd.pem \
  -days 3650 \
  -sha256 \
  -extensions v3_req \
  -extfile etcd-ext.cnf

# =========================
# Verify certificates
# =========================
echo ">>> CHECK ETCD CERTIFICATE VALIDITY..."
openssl x509 -in etcd.pem -noout -dates

echo ">>> CHECK ETCD SAN..."
openssl x509 -in etcd.pem -noout -text | grep -A5 "Subject Alternative Name"

echo ">>> VERIFY ETCD CERTIFICATE WITH CA..."
openssl verify -CAfile ca.pem etcd.pem

echo ">>> CERTIFICATES CREATED:"
ls -l ca.pem ca-key.pem etcd.pem etcd-key.pem

# =========================
# Copy certificates to servers
# =========================
echo ">>> COPYING CERTIFICATES TO ETCD SERVERS..."

for SERVER in "${ETCD_SERVERS[@]}"; do
  echo ">>> Copying certificates to ${SERVER}..."

  ssh -tt "${REMOTE_USER}@${SERVER}" "sudo mkdir -p ${REMOTE_CERT_DIR}"

  scp ca.pem etcd.pem etcd-key.pem "${REMOTE_USER}@${SERVER}:/tmp/"

  ssh -tt "${REMOTE_USER}@${SERVER}" "
    sudo mv /tmp/ca.pem ${REMOTE_CERT_DIR}/ca.pem
    sudo mv /tmp/etcd.pem ${REMOTE_CERT_DIR}/etcd.pem
    sudo mv /tmp/etcd-key.pem ${REMOTE_CERT_DIR}/etcd-key.pem

    sudo chown -R root:root ${REMOTE_CERT_DIR}
    sudo chmod 755 ${REMOTE_CERT_DIR}
    sudo chmod 644 ${REMOTE_CERT_DIR}/ca.pem
    sudo chmod 644 ${REMOTE_CERT_DIR}/etcd.pem
    sudo chmod 600 ${REMOTE_CERT_DIR}/etcd-key.pem

    echo '>>> VERIFY CERTIFICATE ON ${SERVER}:'
    openssl verify -CAfile ${REMOTE_CERT_DIR}/ca.pem ${REMOTE_CERT_DIR}/etcd.pem

    echo '>>> Files on ${SERVER}:'
    sudo ls -l ${REMOTE_CERT_DIR}
  "

  echo ">>> Done copying to ${SERVER}"
done

echo ">>> ALL CERTIFICATES COPIED SUCCESSFULLY."