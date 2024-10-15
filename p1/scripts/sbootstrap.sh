apt-get update -y
apt install net-tools -y
curl -sfL https://get.k3s.io | sh -s - --write-kubeconfig-mode=644
while [ ! -d /vagrant ]; do
echo "Waiting for /vagrant to be ready..."
sleep 2
done
while [ ! -f /var/lib/rancher/k3s/server/node-token ]; do
echo "Waiting for /var/lib/rancher/k3s/server/node-token to be ready..."
sleep 2
done
TOKEN=$(sudo cat /var/lib/rancher/k3s/server/node-token)
echo $TOKEN > /vagrant/token