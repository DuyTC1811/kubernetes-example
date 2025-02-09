cat <<EOF | sudo tee -a /etc/hosts
192.168.56.31 master-01
192.168.56.32 master-02
192.168.56.51 worker-01
192.168.56.52 worker-02
192.168.56.53 worker-03
192.168.56.11 loadbalancer
EOF
sudo reboot