#!/bin/bash
set -xe
ETCD_VER=v3.5.17

echo "---[ TURN OFF SWAP ]---"
sudo swapoff -a
sudo sed -i 's|^\(/swap\.img.*\)|# \1|' /etc/fstab

echo "ETCD VERSION: ${ETCD_VER}"

# choose either URL
GOOGLE_URL=https://storage.googleapis.com/etcd
GITHUB_URL=https://github.com/etcd-io/etcd/releases/download
DOWNLOAD_URL=${GOOGLE_URL}

echo "[ STEP 1 ] --- [ CLEAN UP AND PREPARE TEMPORARY FOLDER ]"
sudo rm -f /tmp/etcd-${ETCD_VER}-linux-amd64.tar.gz
sudo rm -rf /tmp/etcd-download-test && mkdir -p /tmp/etcd-download-test

echo "[ STEP 2 ] --- [ DOWNLOAD AND UNZIP ETCD ]"
curl -L ${DOWNLOAD_URL}/${ETCD_VER}/etcd-${ETCD_VER}-linux-amd64.tar.gz -o /tmp/etcd-${ETCD_VER}-linux-amd64.tar.gz
tar xzvf /tmp/etcd-${ETCD_VER}-linux-amd64.tar.gz -C /tmp/etcd-download-test --strip-components=1
sudo rm -f /tmp/etcd-${ETCD_VER}-linux-amd64.tar.gz

echo "[ STEP 3 ] --- [ MOVE EXECUTABLE FILES TO SYSTEM FOLDER ]"
sudo mv -v /tmp/etcd-download-test/etcd /usr/local/bin
sudo mv -v /tmp/etcd-download-test/etcdctl /usr/local/bin
sudo mv -v /tmp/etcd-download-test/etcdutl /usr/local/bin

echo "[ STEP 4 ] --- [ DELETE TEMPORARY FOLDER ]"
sudo rm -rf /tmp/etcd-download-test

echo "[ STEP 5 ] --- [ CHECK VESION ]"
etcd --version
etcdctl version
etcdutl version
mkdir -p /var/lib/etcd
