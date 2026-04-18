# Cài Rook-Ceph cho Kubernetes (lab guide)

Tài liệu này hướng dẫn triển khai nhanh Rook-Ceph để cung cấp storage cho Kubernetes.

## 1) Điều kiện

- Kubernetes cluster chạy ổn định
- Mỗi worker có ít nhất 1 ổ đĩa trống (không mount, không chứa OS)
- `kubectl` truy cập được cụm

## 2) Cài Volume Snapshot CRDs + Controller

```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/master/client/config/crd/snapshot.storage.k8s.io_volumesnapshotclasses.yaml
kubectl apply -f https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/master/client/config/crd/snapshot.storage.k8s.io_volumesnapshots.yaml
kubectl apply -f https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/master/client/config/crd/snapshot.storage.k8s.io_volumesnapshotcontents.yaml
kubectl apply -f https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/master/deploy/kubernetes/snapshot-controller/rbac-snapshot-controller.yaml
kubectl apply -f https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/master/deploy/kubernetes/snapshot-controller/setup-snapshot-controller.yaml
```

Kiểm tra:

```bash
kubectl get crd | grep volumesnapshot
```

## 3) Cài Rook Operator

```bash
git clone --single-branch --branch v1.17.7 https://github.com/rook/rook.git
cd rook/deploy/examples
kubectl create -f crds.yaml -f common.yaml -f operator.yaml
```

## 4) Cấu hình Ceph cluster

Kiểm tra đĩa trống trên node (`lsblk`) và chỉnh `cluster.yaml`:

```yaml
storage:
  useAllNodes: true
  useAllDevices: true
  deviceFilter: "^(sd[b-z]|nvme[0-9]+n[0-9]+)$"
```

> `deviceFilter` giúp tránh ăn nhầm ổ OS (thường là `sda`).

## 5) Deploy Ceph cluster + StorageClass + Toolbox

```bash
kubectl create -f cluster.yaml
kubectl create -f csi/rbd/storageclass.yaml
kubectl create -f toolbox.yaml
```

## 6) Kiểm tra trạng thái

```bash
kubectl -n rook-ceph exec -it deploy/rook-ceph-tools -- ceph status
kubectl -n rook-ceph exec -it deploy/rook-ceph-tools -- ceph osd status
```

Kỳ vọng:

- `health: HEALTH_OK`
- OSDs `up` và `in`.

## Tài liệu chính thức

- https://rook.io/docs/rook/
