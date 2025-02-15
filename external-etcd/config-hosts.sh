cat <<EOF | sudo tee -a /etc/hosts
192.168.56.31 master-01
192.168.56.32 master-02
192.168.56.51 worker-01
192.168.56.52 worker-02
192.168.56.53 worker-03
192.168.56.11 loadbalancer
EOF
sudo reboot

# cilium install \
#   --namespace kube-system \
#   --set cni.install=true \
#   --set ipam.mode=kubernetes \
#   --set routingMode=native \
#   --set ipv4NativeRoutingCIDR=192.168.0.0/16 \
#   --set enableIPv4=true \
#   --set kubeProxyReplacement=true \
#   --set nodePort.enable=true \
#   --set loadBalancer.mode=snat \
#   --set loadBalancer.algorithm=maglev \
#   --set k8sServiceHost=loadbalancer \
#   --set k8sServicePort=6443