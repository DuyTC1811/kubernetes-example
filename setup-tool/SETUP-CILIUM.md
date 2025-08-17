# Setup Cilium for Kubernetes

## Prerequisites

- A running Kubernetes cluster
- `kubectl` configured to access your cluster
- Helm (optional, for advanced installation)

## 1. Install Helm (if not already installed)

```bash
curl https://baltocdn.com/helm/signing.asc | gpg --dearmor | sudo tee /usr/share/keyrings/helm.gpg > /dev/null
sudo apt-get install apt-transport-https --yes
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list
sudo apt-get update
sudo apt-get install helm
echo -e "\e[34m[ DONE ] INSTALL HELM \e[0m"
echo "--------------------------------------------"
```

## 2. Add Cilium Helm repository

```bash
helm repo add cilium https://helm.cilium.io/
helm repo update
echo -e "\e[34m[ DONE ] ADD CILIUM HELM REPOSITORY \e[0m"
echo "--------------------------------------------"

```

## 3. Install Cilium using Helm

```bash
helm install cilium cilium/cilium --namespace kube-system -f cilium-values.yaml
```

you can customize the `cilium-values.yaml` file to suit your environment. Below is an example of a basic configuration file:

- [File cilium-value](../external-etcd/cilium-value.yaml)

## 4. Verify Cilium installation

```bash
kubectl get pods -n kube-system -l k8s-app=cilium
```

## References

- [Cilium Quick Installation Guide](https://docs.cilium.io/en/stable/gettingstarted/k8s-install-default/)
