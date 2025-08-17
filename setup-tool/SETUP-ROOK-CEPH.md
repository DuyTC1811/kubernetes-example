# Rook Ceph Setup Steps

## 1. Prerequisites

- Kubernetes cluster (v1.16+)
- kubectl configured
- Sufficient nodes and storage

## 2. Install Volume Snapshots

- chạy tất cả các node

```bash
sudo timedatectl set-ntp true
```

```sh
kubectl apply -f https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/master/client/config/crd/snapshot.storage.k8s.io_volumesnapshotclasses.yaml
kubectl apply -f https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/master/client/config/crd/snapshot.storage.k8s.io_volumesnapshots.yaml
kubectl apply -f https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/master/client/config/crd/snapshot.storage.k8s.io_volumesnapshotcontents.yaml
# Controller
kubectl apply -f https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/master/deploy/kubernetes/snapshot-controller/rbac-snapshot-controller.yaml
kubectl apply -f https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/master/deploy/kubernetes/snapshot-controller/setup-snapshot-controller.yaml

# check
kubectl get crd | grep volumesnapshot
```

## 3. Install Rook

- đầu tiên hãy đảm bảo các node của bạn có những ổ đĩa trống chạy lệnh kiểm tra `lsblk` <br>
  lúc này nó sẽ hiển thị các thông tin ổ nơi lưu chữ của bạn

```tex
NAME MAJ:MIN RM  SIZE RO TYPE MOUNTPOINTS
sda    8:0    0   20G  0 disk
├─sda1
│      8:1    0   19G  0 part /
├─sda2
│      8:2    0    1K  0 part
└─sda5
       8:5    0  975M  0 part
sdb    8:16   0   20G  0 disk  <<< chưa chia phân vùng, chưa gắn (mount) đây chính là ổ trống có thể để Rook/Ceph sử dụng làm storage.
```

```sh
# 1. Clone Rook repo
git clone --single-branch --branch v1.17.7 https://github.com/rook/rook.git
cd rook/deploy/examples

# 2. Deploy Rook operator
kubectl create -f crds.yaml -f common.yaml -f operator.yaml
```

- tiếp đó sửa file `cluster.yaml` tìm dòng 267 `#deviceFilter: -> deviceFilter: "^(sd[b-z]|nvme[0-9]+n[0-9]+)$"`<br>
  mục đích quest tất các các node lọc các ổ có thể sử dụng ngoài ngoại trừ ổ `sda` vì nó là ổ của OS

```yaml
storage: # cluster level storage configuration and selection
  useAllNodes: true
  useAllDevices: true
  deviceFilter: "^(sd[b-z]|nvme[0-9]+n[0-9]+)$"
```

- tiếp đó deloyment các file

```bash
# 3. Deploy Ceph cluster
kubectl create -f cluster.yaml

# 4. Deploy storage class
kubectl create -f csi/rbd/storageclass.yaml

# 5. Deploy a toolbox pod for Ceph commands
kubectl create -f toolbox.yaml
```

## 4. Verify Cluster Status

- chờ cho khởi tạo các service rồi kiểm tra

```sh
kubectl -n rook-ceph exec -it deploy/rook-ceph-tools -- ceph status
kubectl -n rook-ceph exec -it deploy/rook-ceph-tools -- ceph osd status
```

```tex
  cluster:
    id:     1cb6a2e2-b3a5-415c-a746-e66bd7e3b447
    health: HEALTH_OK

  services:
    mon: 3 daemons, quorum a,b,c (age 58m)
    mgr: a(active, since 58m), standbys: b
    osd: 4 osds: 4 up (since 58m), 4 in (since 8h)

  data:
    pools:   2 pools, 33 pgs
    objects: 92 objects, 241 MiB
    usage:   838 MiB used, 79 GiB / 80 GiB avail
    pgs:     33 active+clean

ID  HOST        USED  AVAIL  WR OPS  WR DATA  RD OPS  RD DATA  STATE
 0  worker-01   202M  19.8G      0        0       0        0   exists,up
 1  worker-02   223M  19.7G      0        0       0        0   exists,up
 2  worker-03   240M  19.7G      0        0       0        0   exists,up
 3  worker-04   171M  19.8G      0        0       0        0   exists,up
```

---

For more details, see the [Rook Ceph documentation](https://rook.io/docs/rook/v1.13/ceph-quickstart.html).
