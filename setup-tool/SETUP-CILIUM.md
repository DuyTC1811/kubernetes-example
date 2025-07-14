# Setup Cilium for Kubernetes

## Prerequisites

- A running Kubernetes cluster
- `kubectl` configured to access your cluster
- Helm (optional, for advanced installation)

## 1. Install Cilium CLI
- [File cilium-value](../external-etcd/cilium-value.yaml)
```bash
helm upgrade cilium cilium/cilium --namespace kube-system -f cilium-values.yaml
```

## References

- [Cilium Quick Installation Guide](https://docs.cilium.io/en/stable/gettingstarted/k8s-install-default/)