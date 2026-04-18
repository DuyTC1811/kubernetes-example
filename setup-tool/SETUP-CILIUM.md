# Cài Cilium CNI cho Kubernetes bằng Helm

## 1) Điều kiện

- Cụm Kubernetes hoạt động bình thường
- `kubectl` đã trỏ đúng cluster
- Cài `helm`

## 2) Thêm Helm repo của Cilium

```bash
helm repo add cilium https://helm.cilium.io/
helm repo update
```

## 3) Cài Cilium

```bash
helm install cilium cilium/cilium \
  --namespace kube-system \
  -f ../external-etcd/cilium-value.yaml
```

> Có thể thay đổi tham số trong `../external-etcd/cilium-value.yaml` theo môi trường.

## 4) Kiểm tra

```bash
kubectl get pods -n kube-system -l k8s-app=cilium
kubectl -n kube-system get ds cilium
```

## Tài liệu chính thức

- https://docs.cilium.io/en/stable/gettingstarted/k8s-install-default/
