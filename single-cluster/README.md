# Dựng Kubernetes Single Cluster bằng Vagrant (Dễ hiểu)

Tài liệu này mô tả cách dựng nhanh 1 cụm Kubernetes local/lab bằng Vagrant.

## 1) Mục tiêu

- Tạo môi trường lab để học/kịch bản PoC.
- Có 1 control plane + nhiều worker.
- Tự động hóa một phần bằng script trong thư mục.

## 2) File chính

- `Vagrantfile`: định nghĩa VM.
- `config-hosts.sh`: cấu hình hosts giữa các node.
- `install-kube.sh`: cài container runtime + kubeadm/kubelet/kubectl.
- `join-worker.yml`: playbook/yaml để join worker vào cụm.

## 3) Yêu cầu

- Máy local đã cài: `Vagrant`, `VirtualBox` (hoặc provider tương đương).
- CPU/RAM đủ cho số VM bạn cấu hình.
- Kết nối mạng ổn định để kéo package/container image.

## 4) Các bước triển khai

### Bước 1: Tạo máy ảo

```bash
vagrant up
```

### Bước 2: Cấu hình hosts và cài Kubernetes

Trên từng node (hoặc qua provision):

```bash
chmod +x config-hosts.sh install-kube.sh
./config-hosts.sh
./install-kube.sh
```

### Bước 3: Khởi tạo control plane

Trên node master:

```bash
kubeadm init --upload-certs
```

Lưu lại lệnh `kubeadm join` được sinh ra.

### Bước 4: Join worker

- Dùng lệnh join trực tiếp, hoặc
- Dùng file `join-worker.yml` nếu bạn có playbook automation.

## 5) Kiểm tra cụm

```bash
kubectl get nodes -o wide
kubectl get pods -A
```

Nếu node chưa `Ready`, chờ thêm vài phút để CNI và system pod khởi động xong.

## 6) Mẹo xử lý lỗi nhanh

- Kiểm tra swap đã tắt chưa.
- Kiểm tra `kubelet`:
  ```bash
  systemctl status kubelet
  journalctl -u kubelet -f
  ```
- Kiểm tra `containerd`:
  ```bash
  systemctl status containerd
  ```
