cat <<EOF | sudo tee -a /etc/hosts
192.168.56.31 master.dns.local master-01
192.168.56.51 worker.dns.local worker-01
EOF
sudo reboot
