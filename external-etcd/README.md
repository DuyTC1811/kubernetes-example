# Kubernetes HA với External ETCD (Dễ đọc)

Tài liệu này hướng dẫn dựng cụm Kubernetes HA bằng **kubeadm**, tách **ETCD** thành cụm riêng để tăng độ sẵn sàng.

## 1) Mục tiêu kiến trúc

- ETCD chạy độc lập trên 3 node (`etcd-01..03`).
- 2 control plane (`master-01`, `master-02`).
- Nhiều worker node.
- 1 node load balancer (HAProxy) để expose API Server (`:6443`).

Tham khảo sơ đồ: `../images/kubernetes.png`.

## 2) Thành phần trong thư mục này

- `generate-certificates.sh`: tạo CA/cert cho ETCD.
- `install-haproxy.sh`: cài + cấu hình HAProxy.
- `install-etcd.sh`: cài ETCD trên các node ETCD.
- `install-kube.sh`: chuẩn bị node Kubernetes (containerd, kubelet, kubeadm...).
- `kubeadm-config.yaml`: cấu hình `kubeadm init` dùng external ETCD.
- `join-master.yaml`: cấu hình thêm control-plane node.
- `config-hosts.sh`: đồng bộ hosts file.
- `setup-etcd-01.sh`, `setup-etcd-02.sh`, `setup-etcd-03.sh`: script bootstrap từng node ETCD.

## 3) Chuẩn bị môi trường

Ví dụ lab:

| Role | Hostname | IP |
|---|---|---|
| ETCD | etcd-01 | 192.168.56.21 |
| ETCD | etcd-02 | 192.168.56.22 |
| ETCD | etcd-03 | 192.168.56.23 |
| Control Plane | master-01 | 192.168.56.31 |
| Control Plane | master-02 | 192.168.56.32 |
| Worker | worker-01 | 192.168.56.51 |
| Worker | worker-02 | 192.168.56.52 |
| Worker | worker-03 | 192.168.56.53 |
| LB | loadbalancer | 192.168.56.11 |

> Khuyến nghị: đồng bộ thời gian (NTP), tắt swap, mở firewall đúng port trước khi triển khai.

## 4) Luồng triển khai nhanh

### Bước 1: Tạo chứng chỉ ETCD trên máy quản trị

```bash
chmod +x generate-certificates.sh
./generate-certificates.sh
```

Kết quả mong đợi: có `ca.pem`, `etcd.pem`, `etcd-key.pem`.

### Bước 2: Cài HAProxy trên node load balancer

```bash
chmod +x install-haproxy.sh
./install-haproxy.sh
```

Kiểm tra:

```bash
sudo haproxy -c -f /etc/haproxy/haproxy.cfg
```

### Bước 3: Cài và cấu hình ETCD cluster

Chạy script cài ETCD trên 3 node ETCD:

```bash
chmod +x install-etcd.sh
./install-etcd.sh
```

Copy chứng chỉ lên từng node ETCD:

```bash
scp ca.pem etcd.pem etcd-key.pem root@192.168.56.21:/var/lib/etcd
scp ca.pem etcd.pem etcd-key.pem root@192.168.56.22:/var/lib/etcd
scp ca.pem etcd.pem etcd-key.pem root@192.168.56.23:/var/lib/etcd
```

Bootstrap từng node (chạy đúng script theo node):

```bash
# ví dụ trên etcd-01
chmod +x setup-etcd-01.sh
./setup-etcd-01.sh
```

Kiểm tra health toàn cụm ETCD:

```bash
etcdctl \
  --cacert=/var/lib/etcd/ca.pem \
  --cert=/var/lib/etcd/etcd.pem \
  --key=/var/lib/etcd/etcd-key.pem \
  endpoint health -w=table --cluster
```

### Bước 4: Chuẩn bị các node Kubernetes

Trên tất cả master/worker:

```bash
chmod +x install-kube.sh
./install-kube.sh
```

### Bước 5: Khởi tạo control plane đầu tiên

Trên `master-01`:

```bash
kubeadm init --config kubeadm-config.yaml --upload-certs
```

Lưu lại:

- `kubeadm join ...` cho worker.
- `kubeadm join ... --control-plane ...` cho master thứ 2.

### Bước 6: Join master-02 và worker

- Dùng token do `kubeadm init` trả về.
- Có thể tham chiếu `join-master.yaml` để chuẩn hóa cấu hình join control plane.

## 5) Checklist xác minh sau triển khai

```bash
kubectl get nodes -o wide
kubectl get pods -A
kubectl get --raw='/readyz?verbose'
```

Kỳ vọng:

- Tất cả node ở trạng thái `Ready`.
- Control plane components đều `Running`.
- ETCD endpoint health đều `true`.

## 6) Các lỗi thường gặp

- **ETCD không quorum**: kiểm tra IP/port `2379`, `2380`, cert và `initial-cluster`.
- **Master join thất bại**: kiểm tra `certificate-key`, LB `:6443`, SAN trong cert.
- **Node NotReady**: kiểm tra CNI plugin, `containerd`, `kubelet` logs.

## 7) Gợi ý vận hành

- Dùng phiên bản Kubernetes/ETCD đồng bộ giữa các node.
- Sao lưu snapshot ETCD định kỳ.
- Dùng GitOps (ArgoCD) hoặc Kustomize để quản lý manifest triển khai ứng dụng.
