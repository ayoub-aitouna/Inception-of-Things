apt-get update -y
apt install net-tools -y
TOKEN=$(cat /vagrant/token)
curl -sfL https://get.k3s.io | K3S_URL=https://192.168.56.110:6443 K3S_TOKEN=$TOKEN sh -
rm /vagrant/token