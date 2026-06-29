```bash
# 1. Cài Gateway API CRDs chuẩn
kubectl apply --server-side -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.5.1/standard-install.yaml
# Sau đó kiểm tra:
kubectl get crd | grep gateway.networking.k8s.io

kubectl apply -f 01-lb-ip-pool.yaml
kubectl get ciliumloadbalancerippool

kubectl apply -f 02-l2-announcement-policy.yaml
kubectl get ciliuml2announcementpolicy

kubectl apply -f 03-namespace.yaml

kubectl apply -f 04-gateway.yaml
kubectl get gateway -n gateway

kubectl apply -f 05-headlamp-route.yaml
kubectl get httproute -A

kubectl get gateway -n gateway

```